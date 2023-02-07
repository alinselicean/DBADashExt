use [DBADashExt];
go

if object_id('[ext].[alert_overrides]') is null
begin
	create table [ext].[alert_overrides]
	(	[override_id] [int] identity(1,1) not null,
		[alert_id] [int] null,
		[webhook_alert_template] [nvarchar](max) null,
		[email_alert_template] [nvarchar](max) null,
		[alert_level] [tinyint] null,
		[audience] [varchar](256) null,
		[override_audience] [bit] not null,
		[emoji] [varchar](64) null,
		[webhook] varchar(512) null,
		[tag_name] nvarchar(50) null,
		[tag_value] nvarchar(128) null,
		[instance_id] int null,
		[threshold] varchar(max) null,

	constraint [pk_alert_overrides] primary key nonclustered 
	(
		[override_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);

	create clustered index [alert_overrides_alert_id] on [ext].[alert_overrides]
	(
		[alert_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = on, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		);
	alter table [ext].[alert_overrides] add constraint [df_alert_overrides_alert_level]  default ((1)) for [alert_level];
	alter table [ext].[alert_overrides] add constraint [df_alert_overrides_override_audience]  default ((0)) for [override_audience];
end;
