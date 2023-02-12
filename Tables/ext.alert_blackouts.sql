use [DBADashExt];
go

if object_id('[ext].[alert_blackouts]') is null
begin
	create table [ext].[alert_blackouts]
	(	[blackout_id] [int] identity(1,1) not null,
		[alert_id] [int] not null,
		[blackout_schedule] varchar(64) not null,
	constraint [pk_alert_blackouts] primary key clustered 
	(
		[alert_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
end;
