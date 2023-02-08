use [DBADashExt];
go

--drop table if exists [ext].[alert_webhooks];
if object_id('[ext].[alert_webhooks]') is null
begin
	create table [ext].[alert_webhooks]
	(	[id] [int] identity(1,1) not null,
		[name] nvarchar(128) not null,
		[type] varchar(128) not null constraint [df_alert_webhooks_type] default('n/a'),	/* can be Slack, Teams, etc */
		[environment] int not null,
		[environment_name] nvarchar(128) not null,
		[webhook] [varchar](512) not null,
		[username]  as ('sql@cms-'+lower([environment_name])),
		[webhook_id] as [environment_name] + '-' + replace([name],' ', '') persisted

	constraint [pk_alert_webhooks] primary key clustered 
	(
		[id]
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	)
end;
