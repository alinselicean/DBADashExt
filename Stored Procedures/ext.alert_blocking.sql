use [DBADashExt];
go

set quoted_identifier on;
go
if object_id('[ext].[alert_blocking]','P') is null exec('create procedure [ext].[alert_blocking] as begin select 1 end;');
go

alter procedure [ext].[alert_blocking]
(	 @alert_name varchar(128) = 'Blocking - Duration'
	,@tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@is_recursive_call bit = 0
	,@debug bit = 0
)
/*
Adapted from DBADash.com: 

https://dbadash.com/docs/help/alerts/
https://github.com/trimble-oss/dba-dash/blob/main/Docs/alert_samples/blocking.sql

The SP will check both criteria: Duration and Blocked Processes
*/
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	--declare 
	--	 @alert_name varchar(128) = 'Blocking - Duration'
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
	create table #blocking 
	(	Instance NVARCHAR(128) NOT NULL,
		InstanceID int,
		BlockedWaitTime BIGINT NOT NULL,
		BlockedSessionCount INT NOT NULL
	);

	if @debug = 1 raiserror('Checking / Raising [%s] alert',10,1,@alert_name) with nowait;
	set @dynSQL = N'use [##DBADASHDB##];
declare @tagid smallint=-1;
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
	;with CurrentBlocking AS (
		select	i.[InstanceDisplayName],
				bss.[InstanceID],
				bss.[BlockedWaitTime],
				bss.[BlockedSessionCount],
				bss.[SnapshotDateUTC],
				row_number() over(partition by bss.[InstanceID] order by bss.[SnapshotDateUTC] DESC) rnum
		from dbo.BlockingSnapshotSummary BSS 
		join dbo.InstancesMatchingTags(@TagID) i on bss.[InstanceID] = I.[InstanceID]
		where bss.[SnapshotDateUTC] >= dateadd(mi,-3,getutcdate())
	)
	insert into #blocking([Instance],[InstanceID],[BlockedWaitTime], [BlockedSessionCount])
	SELECT	[InstanceDisplayName], 
			[InstanceID],
			[BlockedWaitTime],
			[BlockedSessionCount] 
	from CurrentBlocking
	where [rnum] = 1;
	set @rows_OUT = @@rowcount;
end;';

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	--if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @result = 0
	begin
		if @rows > 0
		begin
			select @delay = coalesce([repeat_notification_interval],0) from [ext].[alerts] where [alert_id] = @alert_id;
			if @debug = 1
			begin
				/* add few dummy rows to test with */
				insert into #Blocking values('SRV-DEMO1', 1, 1000000,100);
				insert into #Blocking values('SRV-DEMO2', 2, 1000000,100);
				insert into #Blocking values('SRV-DEMO3', 3, 1000000,100);
			end;
			if @debug = 1 
			begin
				/* delete instances that are within the "delay" window */
				select 'debug - @delay - to be deleted', @delay as [delay]
				select tgt.*
				from [ext].[alert_history] ah
				inner join #blocking tgt on tgt.[Instance] = ah.[instance]
				inner join [ext].[alerts] a on a.[alert_id] = ah.[alert_id]
				where ah.[alert_id] = @alert_id and ah.[last_occurrence] > dateadd(minute,-@delay,getdate());
			end;
			if @delay > 0
			begin
				/* remove instances that are inside the "delay" period */
				delete tgt
				from #Blocking tgt
				inner join [ext].[alert_history] ah on tgt.[Instance] = ah.[instance]
				inner join [ext].[alerts] a on a.[alert_id] = ah.[alert_id]
				where ah.[alert_id] = @alert_id and ah.[last_occurrence] > dateadd(minute,-@delay,getdate());

				set @rows_debug = @@rowcount;
			end;

			/* build the main blocking list */
			drop table if exists #blk;
			;with blk as 
			(	select b.*
					,cast([ext].fn_get_alert_threshold(@alert_id, @tagname, @tagvalue, b.[InstanceID]) as int) as [threshold]
				from #blocking b
			)
			select blk.* 
			into #blk
			from blk 
			where blk.[threshold] < case when @alert_name = 'Blocking - Duration' then blk.[BlockedWaitTime] else blk.[BlockedSessionCount] end;

			if @debug = 1
			begin
				select 'debug - #blk', * from #blk;
				select 'debug - #blk - history', * from [ext].[alert_history] where [alert_id] = @alert_id;
			end;
			if exists(select 1 from #blk)
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
					from #blk b
					left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
					where ao.[alert_id] = @alert_id
						and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
					union all
					
					select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from [ext].[alert_overrides] ao 
					outer apply (select distinct [instanceid] from #blk) b([InstanceID])
					where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
						and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
					union all

					select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
						(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
						), a.[webhook_alert_template]
					from [ext].[alerts] a
					outer apply (select distinct [instanceid] from #blk) b([InstanceID])
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
					from #blk b
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
						from #blk b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience

						select distinct 'debug - distinct notifications',
							@audience,
							ovr.[webhook],
							ovr.[webhook_alert_template],
							ovr.[email_alert_template]
						from #blk b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience;
					end;

					/* build the message blocks required for the actual alert */
					set @table = (	select 
										td = b.[Instance], '', 
										td = format(b.[BlockedSessionCount],'N0'),'',
										td = format(b.[BlockedWaitTime]/1000.0,'N1'),''
									from #blk b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									for xml path('tr')
								);
					set @instances = stuff((select ',' + b.[Instance] 
											from #blk b
											inner join #ovr ovr on b.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
											order by b.[Instance] for xml path('')),1,1,'');

					select distinct
						@webhook = ovr.[webhook],
						@webhook_alert_template = ovr.[webhook_alert_template],
						@email_alert_template = ovr.[email_alert_template]
					from #blk b
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
							from #blk b
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
				raiserror('No significant blocking issues',10,1) with nowait;
			end;
		end
		else
		begin
			raiserror('No significant blocking issues',10,1) with nowait;
		end;
	end
	else
	begin
		raiserror('There was an error trying to raise the [%s] alert.', 10, 1, @alert_name) with nowait;
	end;

	if @is_recursive_call = 1 return;

	/* Now look for blocking -- number of blocked processes */
	if exists(	select 1 from [ext].[alerts] where [alert_name] = N'Blocking - Processes')
		exec [ext].[alert_blocking] @alert_name = 'Blocking - Processes', @tagname = @tagname, @tagvalue = @tagvalue, @is_recursive_call = 1, @debug = @debug;
end;
go
