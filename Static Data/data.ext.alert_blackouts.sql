use [DBADashExt];
go

-- insert blackout window for the Template alert (id=-2)
insert into [ext].[alert_blackouts]([alert_id],[day_of_week],[blackout_start_time],[blackout_end_time])
select src.[alert_id],src.[day_of_week],src.[blackout_start_time],src.[blackout_end_time]
from 
(	values
		(	-2, -1, '20:00:00','23:00:00')		-- -2 = template alert
) src([alert_id],[day_of_week],[blackout_start_time],[blackout_end_time])
left join [ext].[alert_blackouts] tgt on src.[alert_id] = tgt.[alert_id]
where tgt.[blackout_id] is null;
