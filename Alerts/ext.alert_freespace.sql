use [DBADashExt];
go

set quoted_identifier on;
go

if object_id('[ext].[alert_freespace]','P') is null exec('create procedure [ext].[alert_freespace] as begin select 1 end;');
go

alter procedure [ext].[alert_freespace]
(	 @alert_name varchar(128) = 'Disk Free Space'
	,@tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@is_recursive_call bit = 0
	,@debug bit = 0
)
/*
The SP will check both criteria: Long running queries and Blocked Processes
*/
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	--declare 
	--	 @alert_name varchar(128) = 'Disk Free Space'
	--	,@tagname nvarchar(50) = NULL
	--	,@tagvalue nvarchar(50) = NULL
	--	,@is_recursive_call bit = 0
	--	,@debug bit = 1;
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);

	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @err varchar(max);
	declare @result int;
	declare @table varchar(max);
	declare @delay int;
	declare @rows_debug int;

	declare @default_webhook varchar(256);
	declare @default_audience varchar(512);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);

	declare @webhook varchar(256);
	declare @audience varchar(512);
	declare @webhook_alert_template nvarchar(max);
	declare @email_alert_template nvarchar(max);

	declare @dynSQL nvarchar(4000);
	declare @cmd nvarchar(4000);
	declare @lastAlert datetime;
	declare @instances varchar(max);
	declare @rows int;
	declare @alert_date datetime = getdate();

	if @debug = 1 raiserror('Checking / Raising [%s] alert',10,1,@alert_name) with nowait;
	drop table if exists #results;
	create table #results([alert_id] int, [Instance] nvarchar(128), [InstanceID] int, [DrivesInCritical] int, [DrivesInWarning] int, 
							[DetailsDrivesInCritical] varchar(max), [DetailsDrivesInWarning] varchar(max));
	set @dynSQL = N'use [##DBADashDB##];
declare @tagid smallint=-1;
set	@err_OUT = 0;
set @rows_OUT = 0;
if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADashDB##].dbo.Tags 
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
	(	select [InstanceID], cast([SnapshotDate] as datetime2(3)) as [SnapshotDateUtc] 
		from [##DBADashDB##].dbo.CollectionDates where [Reference] = ''Drives''
	)
	, cte as 
	(	select 
			@alert_id as [alert_id], 
			src.[InstanceDisplayName], 
			src.[InstanceID],
			sum(case when src.[PctFreeSpace] < src.[DriveCriticalThreshold] then 1 else 0 end) as [DrivesInCritical],
			sum(case when src.[PctFreeSpace] < src.[DriveWarningThreshold] then 1 else 0 end) as [DrivesInWarning]
			,coalesce(stuff((	select '';'' + upper(ds.[name]) + '' ('' + format(ds.[TotalGB],''N2'') + ''GB / '' + format(ds.[FreeGB],''N2'') + ''GB / '' + format(ds.[PctFreeSpace] * 100.,''N2'') + ''% free)''
								from [##DBADASHDB##].dbo.DriveStatus ds
								where ds.[InstanceID] = src.[InstanceID] --and ds.[SnapshotDate] = src.[SnapshotDate]
									and ds.[PctFreeSpace] < ds.[DriveCriticalThreshold]
								for xml path('''')
							),1,1,''''),''n/a'') as [DetailsDrivesInCritical]
			,coalesce(stuff((	select '';'' + upper(ds.[name]) + '' ('' + format(ds.[TotalGB],''N2'') + ''GB / '' + format(ds.[FreeGB],''N2'') + ''GB / '' + format(ds.[PctFreeSpace] * 100.,''N2'') + ''% free)''
								from [##DBADASHDB##].dbo.DriveStatus ds
								where ds.[InstanceID] = src.[InstanceID] --and ds.[SnapshotDate] = src.[SnapshotDate]
									and ds.[PctFreeSpace] < ds.[DriveWarningThreshold]
								for xml path('''')
							),1,1,''''),''n/a'') as [DetailsDrivesInWarning]
	from [##DBADashDB##].dbo.DriveStatus src
	inner join [##DBADashDB##].dbo.InstancesMatchingTags(@TagID) i on src.[InstanceID] = I.[InstanceID]
	inner join dates d on d.[InstanceID] = src.[InstanceID] and d.[SnapshotDateUtc] = src.[SnapshotDate]
	inner join [##DBADashDB##].dbo.InstanceInfo ii on src.[InstanceID] = ii.[InstanceID]
	where ii.[IsActive] = 1
	group by src.[InstanceDisplayName], src.[InstanceID]
	)
	insert into #results([alert_id], [Instance], [InstanceID], [DrivesInCritical], [DrivesInWarning],[DetailsDrivesInCritical],[DetailsDrivesInWarning])
	select [alert_id], [InstanceDisplayName], [InstanceID], [DrivesInCritical], [DrivesInWarning], 
		[DetailsDrivesInCritical], [DetailsDrivesInWarning]
	from cte
	where [DrivesInCritical] + [DrivesInWarning] > 0;
	set @rows_OUT = @@rowcount;
end;';

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @alert_id int, @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@alert_id = @alert_id,
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @result = 0
	begin
		if @rows > 0
		begin
			/* build the main blocking list */
			drop table if exists #drv;
			;with drv as 
			(	select b.*
					,cast([ext].fn_get_alert_threshold(@alert_id, @tagname, @tagvalue, b.[InstanceID]) as int) as [threshold]
				from #results b
			)
			select drv.* into #drv from drv;

			if exists(select 1 from #drv)
			begin
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
					from #drv b
					left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
					where ao.[alert_id] = @alert_id
						and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
					union all
					
					select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from [ext].[alert_overrides] ao 
					outer apply (select distinct [instanceid] from #drv) b([InstanceID])
					where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
						and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
					union all

					select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
						(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
						), a.[webhook_alert_template]
					from [ext].[alerts] a
					outer apply (select distinct [instanceid] from #drv) b([InstanceID])
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
					from #drv b
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

					/* build the message blocks required for the actual alert */
					set @table = (	select 
										td = b.[Instance], '', 
										td = format(b.[DrivesInWarning],'N0'),'',
										td = replace(b.[DetailsDrivesInWarning],';','<br/>'), '', 
										td = format(b.[DrivesInCritical],'N0'),'',
										td = replace(b.[DetailsDrivesInCritical],';','<br/>'), ''
									from #drv b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									for xml path('tr')
								);
					set @table = replace(replace(@table,'&lt;','<'),'&gt;','>');
					set @instances = stuff((select ',' + b.[Instance] 
											from #drv b
											inner join #ovr ovr on b.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
											order by b.[Instance] for xml path('')),1,1,'');

					if @debug =  1 select cast(@table as xml);
					select distinct
						@webhook = ovr.[webhook],
						@webhook_alert_template = ovr.[webhook_alert_template],
						@email_alert_template = ovr.[email_alert_template]
					from #drv b
					inner join #ovr ovr on b.[instance] = ovr.[instance]
					inner join #list l on ovr.[audience] = l.[audience]
					where l.[audience] = @audience;

					/* send the notification */
					exec [ext].[send_alert_notification] 
						@alert_name = @alert_name,
						@alert_type = 1,
						@table = @table,
						@instances = @instances,
						@alert_webhook = @webhook,
						@audience = @audience,
						@email_template = @email_alert_template,
						@webhook_template = @webhook_alert_template;

					/* update the [last_occurrence] column for the affected instances */
					merge into [ext].[alert_history] as tgt
					using (	select @alert_id as [alert_id], b.[instance] 
							from #drv b
							inner join #ovr ovr on b.[instance] = ovr.[instance]
							inner join #list l on ovr.[audience] = l.[audience]
							where l.[audience] = @audience) as src
						on (src.[instance] = tgt.[instance] and src.[alert_id] = tgt.[alert_id])
					when matched then
						update set tgt.[last_occurrence] = @alert_date
					when not matched by target then
						insert([instance],[alert_id],[last_occurrence])
						values(src.[instance],src.[alert_id], @alert_date);

					update #list set [done] = 1 where [audience] = @audience;
				end;
			end
			else
			begin
				raiserror('Drives OK',10,1) with nowait;
			end;
		end
		else
		begin
			raiserror('Drives OK',10,1) with nowait;
		end;
	end
	else
	begin
		raiserror('There was an error trying to raise the [%s] alert.', 10, 1, @alert_name) with nowait;
	end;
end;
go
