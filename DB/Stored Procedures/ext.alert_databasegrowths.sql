SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

CREATE procedure [ext].[alert_databasegrowths]
(	@debug bit = 0
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	declare @alert_name varchar(128) = 'DB Growths';
	declare @tagname nvarchar(50), @tagvalue nvarchar(128);
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

	/* get the defaults first */
	select 
		@default_audience = a.[audience],
		@default_email_alert_template = a.[email_alert_template],
		@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
		@default_webhook_alert_template = a.[webhook_alert_template]
	from [ext].[alerts] a
	where a.[alert_id] = @alert_id;

	drop table if exists #results;
	create table #results([alert_id] int, [Instance] nvarchar(128), [InstanceID] int, 
		[DB] varchar(128), [File] nvarchar(128), [sizeMB] decimal(20,3), [TotalGrowth] decimal(20,3), 
		[IsPercentGrowth] varchar(3), [AutoGrowthPct] bigint, [AutogrowthMB] decimal(20,3), [AutogrowCount] int);
	set @dynSQL = N'use [##DBADashDB##];
	insert into #results([alert_id], [Instance], [InstanceID], [DB], [File], [sizeMB], [TotalGrowth], 
		[IsPercentGrowth], [AutoGrowthPct], [AutogrowthMB], [AutogrowCount])
	SELECT @alert_id as [alert_id],
		I.[InstanceDisplayName] as [Instance],
		i.[InstanceID],
		D.[name] AS [DB], 
		F.[name] AS [File],
		F.[size]/128.0 AS [SizeMB],

 		/* Diff between file size now and 2 days ago */
 		(F.[size] - SS.[Size])/128.0 AS [TotalGrowthMB],
		substring(''No Yes'', 3 * F.[is_percent_growth] + 1, 3) as [IsPercentGrowth],
		CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] ELSE NULL END AS [AutoGrowthPct],

		/* Growth in MB  - converting % growth into MB */
		CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] * 0.01 * SS.[Size] ELSE F.[growth] END / 128.0 AS [AutoGrowthMB],
		/* Calculate autogrowth count based on change in size and autogrpowth increment.  Note: Files could have been grown manually */
		CAST((F.[size]-SS.[Size]) / NULLIF(CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] * 0.01 * SS.[Size] ELSE F.[growth] END,0) AS INT) AS AutoGrowCount 
	FROM dbo.[Instances] I 
	JOIN dbo.[Databases] D ON D.[InstanceID] = I.[InstanceID]
	JOIN dbo.[DBFiles] F ON F.[DatabaseID] = D.[DatabaseID]
	OUTER APPLY (SELECT TOP(1) FSS.[Size]
				FROM dbo.[DBFileSnapshot] FSS 
				WHERE FSS.[FileID] = F.[FileID]
				AND FSS.[SnapshotDate] >= CAST(DATEADD(minute,-60,GETUTCDATE()) AS DATETIME2(2))
				ORDER BY FSS.[SnapshotDate]
				) SS /* Get the file size from 1 hour ago */
	WHERE I.[IsActive] = 1
	AND F.[IsActive] = 1
	AND D.[IsActive] = 1
	AND F.[size] - SS.[Size] > 0
';

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];
	exec sp_executesql @stmt = @cmd, 
		@params = N'@alert_id int',
		@alert_id = @alert_id;

	if @debug = 1
		insert into #results([alert_id], [Instance], [InstanceID], [DB], [File], [sizeMB], [TotalGrowth], [IsPercentGrowth], [AutoGrowthPct], [AutogrowthMB], [AutogrowCount])
		select @alert_id, 'SRV-DEMO10', 1, 'DB1', 'C:\SomeFolder\File1.ndf',100,100,'No',NULL,100,1;

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
				and (ao.[tag_name] is null and ao.[tag_value] is null and ao.[instance_id] is not null)
			union all
					
			select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
			from [ext].[alert_overrides] ao 
			outer apply (select distinct [instanceid] from #results) b([InstanceID])
			where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
				and (ao.[tag_name] is not null and ao.[tag_value] is not null and ao.[instance_id] is null)
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
								td = b.[DB], '',
								td = b.[File], '',
								td = format(b.[SizeMB],'N3'),'',
								td = format(b.[TotalGrowth],'N3'),'',
								td = b.[IsPercentGrowth],'',
								td = format(coalesce(b.[AutogrowthPct],0),'N3'),'',
								td = format(b.[AutogrowthMB],'N3'),'',
								td = format(b.[AutogrowCount],'N0'),''
							from #results b
							inner join #ovr ovr on b.[instance] = ovr.[instance]
							inner join #list l on ovr.[audience] = l.[audience]
							where l.[audience] = @audience
							for xml path('tr')
						);
			set @table = replace(replace(@table,'&lt;','<'),'&gt;','>');
			set @instances = stuff((select distinct ',' + b.[Instance] 
									from #results b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									order by ',' + b.[Instance] for xml path('')),1,1,'');

			if @debug =  1 select cast(@table as xml);
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
				@webhook_template = @webhook_alert_template;

			/* update the [last_occurrence] column for the affected instances */
			merge into [ext].[alert_history] as tgt
			using (	select @alert_id as [alert_id], b.[instance] 
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

			update #list set [done] = 1 where [audience] = @audience;
		end;
	end
	else
	begin
		raiserror('No DB growths detected.', 10, 1, @alert_name) with nowait;
	end;
end;
GO
