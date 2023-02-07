use [DBADashExt];
go

if object_id('[ext].[events]') is null
begin
	create table [ext].[events]
	(	[event_id] [int] identity(1,1) not null,
		[event_datetime] [datetime] null,
		[event_source] [nvarchar](100) null,
		[event_type] [nvarchar](100) null,
		[event_text] [nvarchar](max) null
	);

	create clustered index [event_datetime] on [ext].[events]
	(
		[event_datetime] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
	);

	create nonclustered index [event_source] ON [ext].[events]
	(
		[event_source] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
	);
	alter table [ext].[events] add  constraint [df_events_event_datetime]  default (getutcdate()) for [event_datetime];
end;
