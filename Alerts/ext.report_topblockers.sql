use [DBADashExt];
go

if object_id('[ext].[report_topblockers]','P') is null
	exec('create procedure [ext].[report_topblockers] as begin select 1 end;');
go

alter procedure [ext].[report_topblockers]
(	@alert_mode varchar(10) = 'Report'	/* can be Report (default) or Alert */
	,@rerun bit = 0
	,@debug bit = 0
)
as
begin
	set nocount on;

	--declare @alert_mode varchar(10) = 'Alert';		/* can be Report (default) or Alert */
	declare @alert_name varchar(128) = 'Top Head Blockers';
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);
	declare @subject varchar(1024);
	declare @MinutesBack int;
	declare @MinBlockWaitTimeRecursive varchar(10);

	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @err varchar(max);
	declare @result int;
	declare @table varchar(max);
	declare @delay int;
	--declare @rows_debug int;
	declare @tagname nvarchar(50), @tagvalue nvarchar(128);

	declare @default_webhook varchar(256);
	declare @default_audience varchar(512);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);
	declare @thresholds varchar(max);

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
	--declare @debug bit = 1;
	declare @top int = 10;

	if @debug = 1 raiserror('Checking / Raising [%s] alert',10,1,@alert_name) with nowait;
	drop table if exists #results;
	drop table if exists #outcome;
	create table #results(	[Rank] int, [InstanceID] int, [Instance] nvarchar(128), [SQLHandle] varchar(128), 
							[Occurrences] bigint, 
							[TotalBlockCount] bigint, [TotalBlockWaitTimeMs] bigint, 
							[TotalBlockCountRecursive] bigint, [TotalBlockWaitTimeRecursiveMs] bigint,
							[AvgDuration (ms)] bigint, [TopBlockerTSQL] nvarchar(max));
	create table #outcome([rows] int, [err] int);
	set @dynSQL = N'use [##DBADASHDB##];
declare @rows int = 0;
declare @top int = ##TOP##;
##THRESHOLDS##
	;with dates as 
	(	select [InstanceID], cast([SnapshotDate] as datetime2(7)) as [SnapshotDateUtc] 
		from [dbo].[CollectionDates] where [Reference] = ''RunningQueries''
	)
	, cte as 
	(	select 
			src.[SnapshotDateUTC], src.[InstanceID], src.[InstanceDisplayName] as [Instance], src.[database_name], src.[program_name], src.[host_name],
			src.[query_hash],src.[sql_handle],
			src.[batch_text] as [batch_text],
			src.[text] as [query_text],
			src.[status], src.[open_transaction_count], src.[TopSessionWaits], src.[BlockCount], src.[BlockCountRecursive], src.[BlockWaitTimeMs], 
			src.[BlockWaitTimeRecursiveMs], src.[Duration (ms)]
		from [dbo].[RunningQueriesInfo] src 
		inner join [dbo].[InstanceInfo] ii on src.[InstanceID] = ii.[InstanceID]
		inner join dates d on src.[InstanceID] = d.[InstanceID] and src.[SnapshotDateUTC] >= dateadd(minute,-@MinutesBack,d.[SnapshotDateUtc])
		where src.[IsRootBlocker] = 1 
			and (@MinBlockWaitTimeRecursive is null or src.[BlockWaitTimeRecursiveMs] > @MinBlockWaitTimeRecursive)
			and ii.[IsActive] = 1
	)
	,qry as 
	(	select top(@top)
			cte.[InstanceID],
			(select distinct sq.[Instance] from cte sq where sq.[InstanceID] = cte.[InstanceID]) as [Instance],
			cte.[sql_handle] as [SQLHandle],
			count_big(cte.[sql_handle]) as [Occurrences],
			sum(cast(cte.[BlockCount] as bigint)) as [TotalBlockCount],
			sum(cast(cte.[BlockWaitTimeMs] as bigint)) as [TotalBlockWaitTimeMs],
			sum(cast(cte.[BlockCountRecursive] as bigint)) as [TotalBlockCountRecursive],
			sum(cast(cte.[BlockWaitTimeRecursiveMs] as bigint)) as [TotalBlockWaitTimeRecursiveMs],
			avg(cast(cte.[Duration (ms)] as bigint)) as [AvgDuration (ms)]
			,stuff(replace((	select distinct '','' + sq.[query_text] 
								from cte sq where sq.[sql_handle] = cte.[sql_handle] and sq.[InstanceID] = cte.[InstanceID] 
								for xml path('''')),''&#x0D;'',''''),1,1,'''') as [TopBlockerTSQL]
		from cte
		group by cte.[InstanceID], cte.[sql_handle]
	)
	insert into #results(	[Rank], [InstanceID], [Instance], [SQLHandle], [Occurrences], [TotalBlockCount], [TotalBlockWaitTimeMs],
							[TotalBlockCountRecursive], [TotalBlockWaitTimeRecursiveMs], [AvgDuration (ms)], [TopBlockerTSQL])
	select 
		row_number() over(order by [TotalBlockWaitTimeRecursiveMs] desc) as [Rank],
		[InstanceID], [Instance], [SQLHandle], [Occurrences], [TotalBlockCount], [TotalBlockWaitTimeMs],
		[TotalBlockCountRecursive], [TotalBlockWaitTimeRecursiveMs], [AvgDuration (ms)], [TopBlockerTSQL]	
	from qry
	order by [TotalBlockWaitTimeRecursiveMs] desc;
	set @rows = @@rowcount;

	/* insert the outcome details for the caller */
	insert into #outcome([rows],[err]) select @rows, 0;';

	/* Override the default window for Report mode of past 15 minutes when in Alert mode */
	if @alert_mode = 'Report'
	begin
		/* check when report was last run and calculate the difference in minutes since that date. Defaults to last 7 days (10080 minutes) */
		set @MinutesBack = datediff(minute, coalesce((select [last_occurrence] from [ext].[alert_history] where [alert_id] = @alert_id),dateadd(day,-7,getdate())), getdate());
		set @MinBlockWaitTimeRecursive = coalesce((select [value] from [ext].[parameters] where [name] = 'Reports/TopBlockers/MinBlockedWaitTimeMs'),'10000');
		set @top = coalesce((select [value] from [ext].[parameters] where [name] = 'Reports/TopBlockers/TopNRows'),'10');
	end
	else
	begin
		/* Only the top 5 head blockers will be included in the notification when running in Alert mode */
		set @top = 5;
	end;
	if @debug = 1 or @rerun = 1
	begin
		set @MinutesBack = 10080;
	end;
	set @thresholds = case 
						when @alert_mode = 'Alert' then ext.fn_get_alert_threshold(@alert_id, NULL, NULL, NULL)
						else '@MinutesBack int=' + cast(@MinutesBack as varchar(10)) + ',@MinBlockWaitTimeRecursive int=' + @MinBlockWaitTimeRecursive
					end;

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	set @cmd = replace(@cmd, '##THRESHOLDS##', 'declare ' + coalesce(@thresholds,''));
	set @cmd = replace(@cmd, '##TOP##', @top);
	if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];

	exec(@cmd);
	if @debug = 1 select 'debug - initial results', * from #results;

	select @result = coalesce([err],0), @rows = coalesce([rows],0) from #outcome;

	/* get the defaults first */
	select 
		@default_audience = a.[audience],
		@default_email_alert_template = a.[email_alert_template],
		@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
		@default_webhook_alert_template = a.[webhook_alert_template]
	from [ext].[alerts] a
	where a.[alert_id] = @alert_id;

	if @debug = 1 set @rows = 1;
	if @result = 0
	begin
		if @rows > 0
		begin
			if exists(select 1 from #results)
			begin
				/* 
				Get the overrides, if defined. Order of precedence:
				1 (highest) = instance level overrides (instance_id <> NULL, tags = NULLs) - uses ext.alert_overrides
				2 (second) = tag level overrides (instance_id = NULL, tags <> NULLs) - uses ext.alert_overrides
				3 (last, fallback) = alert level definitions - from ext.alerts
				*/
				drop table if exists #ovr;
				with overrides as
				(	select distinct 1 as [precedence], b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from #results b
					left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
					where ao.[alert_id] = @alert_id
						and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
					union all
					
					select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from [ext].[alert_overrides] ao 
					outer apply (select distinct [instanceid] from #results) b([InstanceID])
					where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
						and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
					union all

					select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
						(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
						), a.[webhook_alert_template]
					from [ext].[alerts] a
					outer apply (select distinct [instanceid] from #results) b([InstanceID])
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
					from #results b
					left join overrides o on b.[InstanceID] = o.[InstanceID]
				)
				select *
				into #ovr from ovr where [rn] = 1;

				/* build the driving list of distinct emails */
				drop table if exists #list;
				select distinct [audience], cast(0 as bit) as [done] into #list from #ovr;
				set @subject = case when @alert_mode = 'Report' then 'Top Head Blockers report' else null end;
				if @debug = 1 
				begin
					--update #list set [audience] = 'alin.selicean@gmail.com';
					select 'debug -- #list', * from #list;
				end;

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
						from #results b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience

						select distinct 'debug - distinct notifications',
							@audience,
							ovr.[webhook],
							ovr.[webhook_alert_template],
							ovr.[email_alert_template]
						from #results b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience;
					end;

					/* build the message blocks required for the actual alert */
					set @table = (	select 
										td = b.[Rank], '', 
										td = b.[InstanceID],  '', 
										td = b.[Instance],  '', 
										td = b.[SQLHandle],  '', 
										td = b.[Occurrences],  '', 
										td = b.[TotalBlockCount],  '', 
										td = format(b.[TotalBlockWaitTimeMs] / 1000., 'N2'), '', 
										td = b.[TotalBlockCountRecursive],  '', 
										td = format(b.[TotalBlockWaitTimeRecursiveMs] / 1000., 'N2'),  '', 
										td = format(b.[AvgDuration (ms)],'N0'), '', 
										td = coalesce(nullif(b.[TopBlockerTSQL],''),'n/a'), ''
									from #results b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									for xml path('tr')
								);
					set @instances = stuff((select ',' + b.[Instance] 
											from #results b
											inner join #ovr ovr on b.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
											order by b.[Instance] for xml path('')),1,1,'');

					select distinct
						@webhook = ovr.[webhook],
						@webhook_alert_template = ovr.[webhook_alert_template],
						@email_alert_template = ovr.[email_alert_template]
					from #results b
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
						@subj = @subject,
						@webhook_template = @webhook_alert_template;

					/* update the [last_occurrence] column for the affected instances */
					if @alert_mode = 'Report' and @rerun = 0
					begin
						merge into [ext].[alert_history] as tgt
						using (	select distinct @alert_id as [alert_id], b.[instance] 
								from #results b
								inner join #ovr ovr on b.[instance] = ovr.[instance]
								inner join #list l on ovr.[audience] = l.[audience]
								where l.[audience] = @audience) as src
							on (src.[instance] = tgt.[instance] and src.[alert_id] = tgt.[alert_id])
						when matched then
							update set tgt.[last_occurrence] = @alert_date
						when not matched by target then
							insert([instance],[alert_id],[last_occurrence])
							values(src.[instance],src.[alert_id], @alert_date);
					end;
					update #list set [done] = 1 where [audience] = @audience;
				end;
			end
			else
			begin
				raiserror('No top blockers found',10,1) with nowait;
			end;
		end
		else
		begin
			raiserror('No top blockers found',10,1) with nowait;
		end;
	end;
end;
go
