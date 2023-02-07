use [DBADashExt];
go

insert into [ext].[enum_alert_levels]([level_id],[name])
select src.[level_id],src.[name]
from (
		-- do not change these
	values	 (0,'Normal')
			,(1,'Informational')
			,(2,'Warning')
			,(3,'Critical')
			,(4,'Fatal')
	) src([level_id],[name])
left join [ext].[enum_alert_levels] tgt on src.[level_id] = tgt.[level_id]
where tgt.[level_id] is null;
