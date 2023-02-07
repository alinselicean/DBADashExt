use [DBADashExt];
go

/* insert static data */
set identity_insert [ext].[environment] on;
insert into [ext].[environment]([id],[name],[is_local])
select src.[id],src.[name],src.[is_local]
from (
	-- add / remove entries as you need, only one environment can be local ([is_local] = 1)
	values	 (0,'*',0)
			,(1,'production',1)
			,(2,'internal',0)
			,(3,'stage',0)
	) src([id],[name],[is_local])
left join [ext].[environment] tgt on src.[name] = tgt.[name]
where tgt.[name] is null;
set identity_insert [ext].[environment] off;
