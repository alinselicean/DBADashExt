use [DBADashExt];
go

if object_id('[ext].[alerts]') is null
begin
	create table [ext].[alerts]
	(	[alert_id] [int] identity(1,1) not null,			-- id<0 = special alerts: template, custom & catch-all alerts
		[alert_name] [nvarchar](128) not null,
		[alert_env] int not null,
		[alert_wiki] [varchar](512) null,
		[repeat_notification_interval] [int] null,
		[escalation_interval] [int] null,					-- not used yet, future developments
		[last_notification] [datetime] null,
		[send_to_webhook] [bit] not null,
		[webhook_alert_template] [nvarchar](max) null,
		[email_alert_template] [nvarchar](max) null,
		[audience] [varchar](256) null,
		[alarm_emoji] [varchar](32) null,					-- provided defaults are specific to Slack
		[normal_emoji] [varchar](32) null,					-- provided defaults are specific to Slack
		[continue_emoji] [varchar](32) null,				-- provided defaults are specific to Slack
		[is_muted] [bit] not null,
		[default_threshold] varchar(max) null,

	constraint [PK_alerts] primary key clustered 
	(
		[alert_name] ASC,
		[alert_env] ASC
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
	alter table [ext].[alerts] add  constraint [df_alerts_alert_env]  default ('internal') for [alert_env];
	alter table [ext].[alerts] add  constraint [df_alerts_send_to_webhook]  default ((0)) for [send_to_webhook];
	alter table [ext].[alerts] add  constraint [df_alerts_alarm_emoji]  default (',"icon_emoji": ":bell_red:"') for [alarm_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_normal_emoji]  default (',"icon_emoji": ":bell_green:"') for [normal_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_continue_emoji]  default (',"icon_emoji": ":bell_orange:"') for [continue_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_is_muted]  default ((0)) for [is_muted];
end;
