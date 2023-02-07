declare @thresholds varchar(max);
declare @dynSQL varchar(max);
declare @cmd varchar(max);
declare @vars varchar(max);
declare @delay int = 15;

drop table if exists #results;
create table #results([alert_id] int, [InstanceID] int, [Instance] nvarchar(128), [counter] varchar(max));

declare @thresholds varchar(max);
set @thresholds = '@LastMinutes int=##DELAY##;@LRPThreshold int=100000;@TDBWaitCountThreshold int=1;@TDBWaitTimeThreshold int=10000;@CriticalWaitCountThreshold int=1;@CriticalWaitTimeThreshold int=10000';

set @vars = 'declare ' + stuff((select ',' + [value] from string_split(@thresholds,';') for xml path('')),1,1,'');
set @dynSQL = 'use [##DBADASHDB##];
declare @tagid smallint=-1;
declare @p_TagName nvarchar(50) = ##TAGNAME##;
declare @p_TagValue nvarchar(128) = ##TAGVALUE##;
declare @err int = 0
declare @rows int = 0;
declare @alert_id int = ##ALERT_ID##;
##THRESHOLDS##;

if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADASHDB##].dbo.Tags 
	where [TagName] = @p_TagName and [TagValue] = @p_TagValue;
	if @@rowcount=0
	begin
		set @err = -1;
		raiserror(''Tag not found'',11,1) with nowait;
	end
end;

;with dates as 
(	select [InstanceID], cast(dateadd(minute,-@LastMinutes,[SnapshotDate]) as datetime2(7)) as [SnapshotDateUtc] 
	from [DBADash].dbo.CollectionDates where [Reference] = ''RunningQueries''
)
, raw as 
(	select
		src.[InstanceID]
		,case when src.[LongestRunningQueryMs] > @LRPThreshold				then src.[LongestRunningQueryMs]	else null end as [LongestRunningQueryMs]
		,case when src.[TempDBWaitCount] > @TDBWaitCountThreshold			then src.[TempDBWaitCount]			else null end as [TempDBWaitCount]
		,case when src.[TempDBWaitTimeMs] > @TDBWaitTimeThreshold			then src.[TempDBWaitTimeMs]			else null end as [TempDBWaitTimeMs]
		,case when src.[CriticalWaitCount] > @CriticalWaitCountThreshold	then src.[CriticalWaitCount]		else null end as [CriticalWaitCount]
		,case when src.[CriticalWaitTime] > @CriticalWaitTimeThreshold		then src.[CriticalWaitTime]			else null end as [CriticalWaitTime]
	from [##DBADASHDB##].dbo.RunningQueriesSummary src
	inner join [##DBADashDB##].dbo.InstancesMatchingTags(@TagID) i on src.[InstanceID] = I.[InstanceID]
	inner join dates d on d.[InstanceID] = src.[InstanceID] 
	where src.[SnapshotDateUtc] > d.[SnapshotDateUtc]
)
, cte as 
(	select * from raw 
	where  (coalesce([LongestRunningQueryMs],0) +
			coalesce([TempDBWaitCount]		,0) +
			coalesce([TempDBWaitTimeMs]		,0) +
			coalesce([CriticalWaitCount]	,0) +
			coalesce([CriticalWaitTime]		,0)) > 0
)
,rpt as
(	select distinct
		cte.[InstanceID],
		count([LongestRunningQueryMs])	as [#_of_LongestRunningQueryMs],
		count([TempDBWaitCount])		as [#_of_TempDBWaitCount],
		count([TempDBWaitTimeMs])		as [#_of_TempDBWaitTimeMs],
		count([CriticalWaitCount])		as [#_of_CriticalWaitCount],
		count([CriticalWaitTime]) 		as [#_of_CriticalWaitTime],

		coalesce(max([LongestRunningQueryMs]),0)	as [max_of_LongestRunningQueryMs],
		coalesce(max([TempDBWaitCount])	,0)			as [max_of_TempDBWaitCount],
		coalesce(max([TempDBWaitTimeMs]),0)			as [max_of_TempDBWaitTimeMs],
		coalesce(max([CriticalWaitCount]),0)		as [max_of_CriticalWaitCount],
		coalesce(max([CriticalWaitTime]),0)			as [max_of_CriticalWaitTime],

		coalesce(min([LongestRunningQueryMs]),0)	as [min_of_LongestRunningQueryMs],
		coalesce(min([TempDBWaitCount])	,0)			as [min_of_TempDBWaitCount],
		coalesce(min([TempDBWaitTimeMs]),0)			as [min_of_TempDBWaitTimeMs],
		coalesce(min([CriticalWaitCount]),0)		as [min_of_CriticalWaitCount],
		coalesce(min([CriticalWaitTime]),0)			as [min_of_CriticalWaitTime],

		coalesce(avg([LongestRunningQueryMs]),0)	as [avg_of_LongestRunningQueryMs],
		coalesce(avg([TempDBWaitCount])		,0)		as [avg_of_TempDBWaitCount],
		coalesce(avg([TempDBWaitTimeMs])	,0)		as [avg_of_TempDBWaitTimeMs],
		coalesce(avg([CriticalWaitCount])	,0)		as [avg_of_CriticalWaitCount],
		coalesce(avg([CriticalWaitTime]) 	,0)		as [avg_of_CriticalWaitTime]
	from cte
	group by cte.[InstanceID]
)
insert into #results([alert_id], [instanceid], [instance], [counter])
select 
	@alert_id as [alert_id],
	rpt.[InstanceID],
	ii.[InstanceDisplayName] as [Instance],
	concat(	''LongQueries:''		,[#_of_LongestRunningQueryMs]	,''(M:'',[max_of_LongestRunningQueryMs]	,''ms; m:'',[min_of_LongestRunningQueryMs]	,''ms; A:'',[avg_of_LongestRunningQueryMs]	,''ms)'',''<br/>'',
			''TempDBWaitCount:''	,[#_of_TempDBWaitCount]			,''(M:'',[max_of_TempDBWaitCount]		,''; m:'',[min_of_TempDBWaitCount]			,''; A:'',[avg_of_TempDBWaitCount]			,'')'',''<br/>'',
			''TempDBWaitTime:''		,[#_of_TempDBWaitTimeMs]		,''(M:'',[max_of_TempDBWaitTimeMs]		,''ms; m:'',[min_of_TempDBWaitTimeMs]			,''ms; A:'',[avg_of_TempDBWaitTimeMs]	,''ms)'',''<br/>'',
			''CriticalWaitCount:''	,[#_of_CriticalWaitCount]		,''(M:'',[max_of_CriticalWaitCount]		,''; m:'',[min_of_CriticalWaitCount]		,''; A:'',[avg_of_CriticalWaitCount]		,'')'',''<br/>'',
			''CriticalWaitTime:''	,[#_of_CriticalWaitTime]		,''(M:'',[max_of_CriticalWaitTime]		,''ms; m:'',[min_of_CriticalWaitTime]			,''ms; A:'',[avg_of_CriticalWaitTime]	,''ms)''
		) as [counter]
from rpt
inner join [##DBADASHDB##].[dbo].[InstanceInfo] ii on ii.[InstanceID] = rpt.[InstanceID]
where ii.[IsActive] = 1
order by [Instance]
;';

set @cmd = @dynSQL;
set @cmd = replace(@cmd, '##DBADASHDB##','DBADash');
-- order is important!! First the generic thresholds are injected, then the additional DELAY parameter is injected
set @cmd = replace(@cmd, '##THRESHOLDS##', @vars);
set @cmd = replace(@cmd, '##DELAY##', @delay);
set @cmd = replace(@cmd, '##ALERT_ID##', 10);
set @cmd = replace(@cmd, '##TAGNAME##', 'NULL');
set @cmd = replace(@cmd, '##TAGVALUE##', 'NULL');

select cast('<?q-- ' + @cmd + ' --?>' as xml);
exec(@cmd);

select * from #results;
