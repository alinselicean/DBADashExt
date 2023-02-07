if object_id('[ext].[enum_alert_levels]') is null
begin
	create table [ext].[enum_alert_levels]
	(	[level_id] [tinyint] not null,
		[name] [nvarchar](64) not null,
	 constraint [pk_enum_alert_levels] primary key clustered 
	(
		[level_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off,
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
end;
