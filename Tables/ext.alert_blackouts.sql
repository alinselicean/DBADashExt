use [DBADashExt];
go

if object_id('[ext].[alert_blackouts]') is null
begin
	create table [ext].[alert_blackouts]
	(	[blackout_id] [int] identity(1,1) not null,
		[alert_id] [int] not null,
		[day_of_week] tinyint not null constraint [ck_alert_blackouts_day_of_week] check ([day_of_week] between 1 and 7),
		[start_time] time not null,
		[end_time] time not null constraint [ck_alert_blackouts_end_time] check ([end_time] > [start_time]),
		[start_h] as datepart(hour, [start_time]) persisted,
		[start_m] as datepart(minute, [start_time]) persisted,
		[end_h] as datepart(hour, [end_time]) persisted,
		[end_m] as datepart(minute, [end_time]) persisted,

	constraint [pk_alert_blackouts] primary key clustered 
	(
		[blackout_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
end;
