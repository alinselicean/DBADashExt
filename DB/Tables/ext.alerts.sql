CREATE TABLE [ext].[alerts]
(
[alert_id] [int] NOT NULL IDENTITY(1, 1),
[alert_name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[alert_env] [int] NOT NULL CONSTRAINT [df_alerts_alert_env] DEFAULT ('internal'),
[alert_wiki] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[repeat_notification_interval] [int] NULL,
[escalation_interval] [int] NULL,
[last_notification] [datetime] NULL,
[send_to_webhook] [bit] NOT NULL CONSTRAINT [df_alerts_send_to_webhook] DEFAULT ((0)),
[webhook_alert_template] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[email_alert_template] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[audience] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[alarm_emoji] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [df_alerts_alarm_emoji] DEFAULT (',"icon_emoji": ":bell_red:"'),
[normal_emoji] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [df_alerts_normal_emoji] DEFAULT (',"icon_emoji": ":bell_green:"'),
[continue_emoji] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL CONSTRAINT [df_alerts_continue_emoji] DEFAULT (',"icon_emoji": ":bell_orange:"'),
[is_muted] [bit] NOT NULL CONSTRAINT [df_alerts_is_muted] DEFAULT ((0)),
[default_threshold] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [ext].[alerts] ADD CONSTRAINT [PK_alerts] PRIMARY KEY CLUSTERED ([alert_name], [alert_env]) ON [PRIMARY]
GO
