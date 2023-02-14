SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE procedure [ext].[alert_cpu]
(	 @tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@debug bit = 0
)
as
begin
	set nocount on;
	--declare 	 
	--	 @tagname nvarchar(50) = NULL
	--	,@tagvalue nvarchar(50) = NULL
	--	,@debug bit = 1

	declare @alert_name nvarchar(128) = N'High CPU';
	declare @threshold int = coalesce((select [default_threshold] from [ext].[alerts] where [alert_name] = @alert_name),80);
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);
	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @alert_date datetime = getdate();
	declare @table_ON nvarchar(max);
	declare @instances_ON nvarchar(max);
	declare @table_OFF nvarchar(max);
	declare @instances_OFF nvarchar(max);
	declare @dynSQL nvarchar(4000);
	declare @cmd nvarchar(4000);
	declare @rows int;
	declare @result int;

	declare @default_webhook varchar(512);
	declare @default_audience varchar(256);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);

	declare @webhook varchar(512);
	declare @audience varchar(256);
	declare @webhook_alert_template nvarchar(max);
	declare @email_alert_template nvarchar(max);

	drop table if exists #results;
	drop table if exists #cpu;
	create table #results([alert_id] int, [Instance] nvarchar(128), [Counter] int, [InstanceID] int);
	set @dynSQL = N'use [##DBADashDB##];
declare @tagid smallint=-1;
declare @alert_id int = ##ALERT_ID##;

set	@err_OUT = 0;
set @rows_OUT = 0;

if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADASHDB##].dbo.Tags 
	where [TagName] = @p_TagName and [TagValue] = @p_TagValue;
	if @@rowcount=0
	begin
		set @err_OUT = -1;
		raiserror(''Tag not found'',11,1) with nowait;
	end
end;

if @err_OUT = 0
begin
	;with dates as 
	(	select [InstanceID], cast([SnapshotDate] as datetime2(3)) as [EventTime] 
		from [##DBADashDB##].dbo.CollectionDates where [Reference] = ''CPU''
	)
	, cte as 
	(	select 
			@alert_id as [alert_id], 
			ii.[InstanceDisplayName], 
			ii.[InstanceID],
			cpu.[TotalCPU] as [counter], 
			row_number() over(partition by cpu.[InstanceId] order by cpu.[EventTime] desc) as [rn]
	from [##DBADashDB##].dbo.CPU
	inner join [##DBADashDB##].dbo.InstancesMatchingTags(@TagID) i on cpu.[InstanceID] = I.[InstanceID]
	inner join dates d on d.[InstanceID] = cpu.[InstanceID] 
	inner join [##DBADashDB##].dbo.InstanceInfo ii on cpu.[InstanceID] = ii.[InstanceID]
	where cpu.[EventTime] >= dateadd(minute,-2,d.[EventTime]) and ii.[IsActive] = 1
	)
	select [alert_id], [InstanceDisplayName], [Counter], [InstanceID] from cte where [rn] = 1;
	set @rows_OUT = @@rowcount;
end;';
	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	set @cmd = replace(@cmd, '##ALERT_ID##', @alert_id);	

	insert into #results([alert_id], [Instance], [Counter], [InstanceID])
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @rows > 0
	begin
		;with th as 
		(select 
			cpu.*,
			cast([ext].[fn_get_alert_threshold](cpu.[alert_id], @tagName, @tagValue, cpu.[InstanceID]) as int) as [threshold]
		from #results cpu
		)
		select
			th.*
			,ah.[status]
			,cast(
			case 
				-- instance is not in the history and is above threshold ==> add it and set alarm status to ON
				when ah.[alert_id] is null and th.[Counter] >= th.[threshold] then 'NEW->ON'
				-- instance is not in the history and is below threshold ==> ignore it
				when ah.[alert_id] is null and th.[Counter] < th.[threshold] then 'IGNORE'
				-- instance is in the history, alarm state is ON AND cpu is less than the threshold ==> switch the alarm state to OFF
				when ah.[alert_id] is not null and ah.[status] = 'ON' and th.[Counter] < th.[threshold] then 'ON->OFF'
				-- instance is in the history, alarm state is ON AND cpu is still greater than the threshold ==> ignore it
				when ah.[alert_id] is not null and ah.[status] = 'ON' and th.[Counter] >= th.[threshold] then 'IGNORE'
				-- instance is in the history, alarm state is OFF AND cpu is greater than the threshold ==> switch the alarm state to ON
				when ah.[alert_id] is not null and ah.[status] = 'OFF' and th.[Counter] >= th.[threshold] then 'OFF->ON'
				-- instance is in the history, alarm state is OFF AND cpu is less than the threshold ==> ignore it
				when ah.[alert_id] is not null and ah.[status] = 'OFF' and th.[Counter] < th.[threshold] then 'IGNORE'
			end as varchar(20)) as [action]	
		into #cpu
		-- #results + [threshold] + [status] + [action]
		from th  
		left join [ext].[alert_history] ah on th.[alert_id] = ah.[alert_id] and th.[Instance] = ah.[instance];

		if @debug = 1
		begin
			/* add few dummy rows to test with */
			-- [alert_id], [Counter], [Instance], [InstanceID], [threshold], [status], [action]
			insert into #cpu([alert_id], [Counter], [Instance], [InstanceID], [threshold], [status], [action])
			values	 (3, 35,'SRV-DEMO01',1,10,'OFF','OFF->ON')
					,(3, 55,'SRV-DEMO02',2,10,'OFF','OFF->ON')
					,(3, 83,'SRV-DEMO03',3,10,'OFF','OFF->ON');
		end;

		/* get the defaults first */
		select 
			@default_audience = a.[audience],
			@default_email_alert_template = a.[email_alert_template],
			@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
			@default_webhook_alert_template = a.[webhook_alert_template]
		from [ext].[alerts] a
		where a.[alert_id] = @alert_id;

		/* 
		Get the overrides, if defined. Order of precedence:
		1 (highest) = instance level overrides (instance_id <> NULL, tags = NULLs) - uses ext.alert_overrides
		2 (second) = tag level overrides (instance_id = NULL, tags <> NULLs) - uses ext.alert_overrides
		3 (last, fallback) = alert level definitions - from ext.alerts
		*/
		drop table if exists #ovr;
		with overrides as
		(	select distinct 1 as [precedence], b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
			from #cpu b
			left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
			where ao.[alert_id] = @alert_id
				and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
			union all
					
			select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
			from [ext].[alert_overrides] ao 
			outer apply (select distinct [instanceid] from #cpu) b([InstanceID])
			where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
				and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
			union all

			select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
				(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
				), a.[webhook_alert_template]
			from [ext].[alerts] a
			outer apply (select distinct [instanceid] from #cpu) b([InstanceID])
			where a.[alert_id] = @alert_id 
		)
		, ovr as 
		(	select 
				row_number() over(partition by o.[instanceid] order by o.[precedence]) as rn,
				b.*, 
				coalesce(o.[audience], @default_audience) as [audience], 
				coalesce(o.[email_alert_template], @default_email_alert_template) as [email_alert_template], 
				coalesce(o.[webhook], @default_webhook) as [webhook], 
				coalesce(o.[webhook_alert_template], @default_webhook_alert_template) as [webhook_alert_template]
			from #cpu b
			left join overrides o on b.[InstanceID] = o.[InstanceID]
		)
		select *
		into #ovr from ovr where [rn] = 1;

		/* build the driving list of distinct emails */
		drop table if exists #list;
		select distinct [audience], cast(0 as bit) as [done] into #list from #ovr;
				
		while 1=1
		begin
			select top 1 
				@audience = [audience]
			from #list where [done] = 0;
			if @@rowcount = 0 break;

			raiserror('Sending notifications for alert [%s] to [%s] recipients', 10, 1, @alert_name, @audience) with nowait;
			if @debug = 1
			begin
				select 'debug - merge', @audience, @alert_id as [alert_id], b.[instance], ovr.* 
				from #cpu b
				inner join #ovr ovr on b.[instance] = ovr.[instance]
				inner join #list l on ovr.[audience] = l.[audience]
				where l.[audience] = @audience

				select distinct 'debug - distinct notifications',
					@audience,
					ovr.[webhook],
					ovr.[webhook_alert_template],
					ovr.[email_alert_template]
				from #cpu b
				inner join #ovr ovr on b.[instance] = ovr.[instance]
				inner join #list l on ovr.[audience] = l.[audience]
				where l.[audience] = @audience;
			end;

			/* process the results */
			/* get the instances that are going ON (High CPU) */
			set @instances_ON = stuff((	select ',' + cpu.[Instance]
										from #cpu cpu
										inner join #ovr ovr on cpu.[instance] = ovr.[instance]
										inner join #list l on ovr.[audience] = l.[audience]
										where l.[audience] = @audience
											and cpu.[action] in ('NEW->ON','OFF->ON')
										order by cpu.[Instance]
										for xml path('')
								),1,1,'');
			set @table_ON = (	select 
									td = cpu.[Instance],'',
									td = cpu.[Counter], '',
									td = cpu.[threshold], ''
								from #cpu cpu
								inner join #ovr ovr on cpu.[instance] = ovr.[instance]
								inner join #list l on ovr.[audience] = l.[audience]
								where l.[audience] = @audience
									and cpu.[action] in ('NEW->ON','OFF->ON')
								order by cpu.[Instance]
								for xml path('tr')
							);

			/* get the instances that are going OFF (CPU recovered) */
			set @instances_OFF = stuff((	select ',' + cpu.[Instance]
											from #cpu cpu
											inner join #ovr ovr on cpu.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
												and cpu.[action] = 'ON->OFF'
											order by cpu.[Instance]
											for xml path('')
									),1,1,'');
			set @table_OFF = (	select
									td = cpu.[Instance],'',
									td = cpu.[Counter], '',
									td = cpu.[threshold], ''
								from #cpu cpu
								inner join #ovr ovr on cpu.[instance] = ovr.[instance]
								inner join #list l on ovr.[audience] = l.[audience]
								where l.[audience] = @audience
									and cpu.[action] = 'ON->OFF'
								order by cpu.[Instance]
								for xml path('tr')
							);

			/* get the specific comm settings */
			select distinct
				@webhook = ovr.[webhook],
				@webhook_alert_template = ovr.[webhook_alert_template],
				@email_alert_template = ovr.[email_alert_template]
			from #cpu b
			inner join #ovr ovr on b.[instance] = ovr.[instance]
			inner join #list l on ovr.[audience] = l.[audience]
			where l.[audience] = @audience;

			/* good news first... send the recovery notifications */
			if @table_OFF is not null
			begin
				set @alert_name = 'High CPU - Recovery';
				raiserror('[%s]: Instances: %s; Table: %s',10,1,@alert_name, @instances_OFF, @table_OFF) with nowait;
				exec [ext].[send_alert_notification] 
					@alert_name = @alert_name,
					@alert_type = 0,
					@table = @table_OFF,
					@instances = @instances_OFF,
					@audience = @audience,
					@alert_webhook = @webhook,
					@email_template = @email_alert_template,
					@webhook_template = @webhook_alert_template;
			end;

			/* ...and now with the bad news */
			if @table_ON is not null
			begin
				set @alert_name = 'High CPU';
				raiserror('[%s]: Instances: %s; Table: %s',10,1,@alert_name, @instances_ON, @table_ON) with nowait;
				exec [ext].[send_alert_notification] 
					@alert_name = @alert_name,
					@alert_type = 0,
					@table = @table_ON,
					@instances = @instances_ON,
					@audience = @audience,
					@alert_webhook = @webhook,
					@email_template = @email_alert_template,
					@webhook_template = @webhook_alert_template;
			end;

			update #list set [done] = 1 where [audience] = @audience;
		end;

		if exists(	select 1 from #cpu where [action] <> 'IGNORE')
		begin
			/* record statuses */
			insert into [ext].[alert_history]([alert_id],[instance],[last_occurrence],[last_value],[status])
			select cpu.[alert_id], cpu.[Instance],@alert_date,cpu.[Counter],'ON'
			from #cpu cpu 
			where cpu.[action] = 'NEW->ON';

			update tgt
				set [last_value] = cpu.[Counter], 
					[last_occurrence] = @alert_date,
					[status] = case when cpu.[action] = 'ON->OFF' then 'OFF' else 'ON' end
			from #cpu cpu
			inner join [ext].[alert_history] tgt on tgt.[alert_id] = cpu.[alert_id] and tgt.[instance] = cpu.[Instance]
			where cpu.[action] in ('OFF->ON', 'ON->OFF');
		end
		else
		begin
			raiserror('No change',10,1) with nowait;
		end;
	end;
end;
GO
