use [DBADashExt];
go

truncate table [ext].[alert_blackouts];

-- insert blackout window for the Template alert (id=-2)
insert into [ext].[alert_blackouts]([alert_id],[day_of_week],[start_time],[end_time])
select src.[alert_id],src.[day_of_week],src.[start_time],src.[end_time]
from 
(	values
		(	-2, 0, '20:00:00','23:00:00')		-- alert_id = -2 => template alert, day_of_week = 0 => all days
) src([alert_id],[day_of_week],[start_time],[end_time])
left join [ext].[alert_blackouts] tgt on src.[alert_id] = tgt.[alert_id]
where tgt.[blackout_id] is null;
