use [DBADashExt];
go

if object_id('[ext].[alert_blackouts]') is null
begin
	create table [ext].[alert_blackouts]
	(	[blackout_id] [int] identity(1,1) not null,
		[alert_id] [int] not null,
		[day_of_week] [int] not null,
		[blackout_start_time] [varchar](8) not null,
		[blackout_end_time] [varchar](8) not null,
	constraint [pk_alert_blackouts] primary key nonclustered 
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

	create clustered index [alert_id] on [ext].[alert_blackouts]
	(
		[alert_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		);
end;
