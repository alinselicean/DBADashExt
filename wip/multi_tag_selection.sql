declare @tagid smallint=-1;
/*
Targeted tag names & values 
			Tag1:value1,value2;Tag2:value1,value2

JSONified: 
{	"name": "Tag1"; "value": ["value1","value2"]; 
	"name": "Tag2"; "value": ["value1","value2"]; 
}

	"name": "Tag1": "value": ["value1","value2"]; 
	"name": "Tag2": "value": ["value1","value2"];
*/
declare @tags nvarchar(max);
declare @jsonTags nvarchar(max);

drop table if exists #instanceTags;
drop table if exists #currentBlocking;
drop table if exists #tags;
create table #instanceTags([InstanceID] int, [TagName] nvarchar(50), [TagValue] nvarchar(128));
create table #currentBlocking(	[Instance] nvarchar(128), [InstanceID] int, 
								[BlockedWaitTime] bigint, [BlockedSessionCount] int,
								[TagName] nvarchar(50), [TagValue] nvarchar(128));
create table #tags([TagName] nvarchar(50), [TagValue] nvarchar(128));

--set @tags = N'{PatchLevel}:SQL 2017 RTM CU23;{PatchLevel}:SQL 2017 RTM CU30'--;Tag3:value3,value4';
set @jsonTags = '[{' + 
					'"name" : "' + replace(replace(replace(replace(@tags,':','| "values" : ["'),',','","'),';','"]}, {"name": "'),'|','", ') + '"]' +
				'}]';

if isjson(@jsonTags) = 1
begin
	insert into #tags([TagName], [TagValue])
	select [TagName], [TagValue] from openjson(@jsonTags)
	with (	[TagName] nvarchar(50) '$.name',
			[TagValues] nvarchar(max) '$.values' as JSON)
	outer apply openjson([TagValues]) with ([TagValue] nvarchar(128) '$');
end;

/* Get the tag names and values for all instances -- we'll filter on them later */
insert into #instanceTags([InstanceID], [TagName], [TagValue])
select ii.[InstanceID], t.[TagName], t.[TagValue]
from [DBADash].[dbo].InstanceInfo ii
left join [DBADash].[dbo].InstanceIDsTags it on it.[InstanceID] = ii.[InstanceID]
inner join [DBADash].[dbo].Tags t on it.[TagID] = t.[TagID]

;with CurrentBlocking AS (
	select	i.[InstanceDisplayName],
			bss.[InstanceID],
			bss.[BlockedWaitTime],
			bss.[BlockedSessionCount],
			bss.[SnapshotDateUTC],
			row_number() over(partition by bss.[InstanceID] order by bss.[SnapshotDateUTC] DESC) rnum
	from [DBADash].dbo.BlockingSnapshotSummary BSS 
	inner join [DBADash].[dbo].InstanceInfo i on bss.[InstanceID] = i.[InstanceID]
	where bss.[SnapshotDateUTC] >= dateadd(mi,-15,getutcdate())
)
--insert into #currentBlocking([Instance],[InstanceID],[BlockedWaitTime], [BlockedSessionCount], [TagName], [TagValue])
SELECT distinct	rnum,
		cb.[InstanceDisplayName], 
		cb.[InstanceID],
		cb.[BlockedWaitTime],
		cb.[BlockedSessionCount]
		--,it.[TagName], it.[TagValue]
		,t.[TagName], t.[TagValue]
		,[DBADashExt].[ext].[fn_get_alert_threshold](1,t.[TagName], t.[TagValue], cb.[InstanceID]) as [threshold]
		,[DBADashExt].[ext].[fn_get_alert_threshold](2,t.[TagName], t.[TagValue], cb.[InstanceID]) as [threshold]
from CurrentBlocking cb
left join #instanceTags it on cb.[InstanceID] = it.[InstanceID]
left join #tags t on t.[TagName] = it.[TagName] and t.[TagValue] = it.[TagValue]
where 1=1
	and [rnum] = 1
	and (@tags is null or (t.[TagName] is not null and t.[TagValue] is not null));

