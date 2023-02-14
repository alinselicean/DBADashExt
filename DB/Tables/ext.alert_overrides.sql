CREATE TABLE [ext].[alert_overrides]
(
[override_id] [int] NOT NULL IDENTITY(1, 1),
[alert_id] [int] NULL,
[webhook_alert_template] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[email_alert_template] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[alert_level] [tinyint] NULL CONSTRAINT [df_alert_overrides_alert_level] DEFAULT ((1)),
[audience] [varchar] (256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[override_audience] [bit] NOT NULL CONSTRAINT [df_alert_overrides_override_audience] DEFAULT ((0)),
[emoji] [varchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[webhook] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[tag_name] [nvarchar] (50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[tag_value] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[instance_id] [int] NULL,
[threshold] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [ext].[alert_overrides] ADD CONSTRAINT [pk_alert_overrides] PRIMARY KEY NONCLUSTERED ([override_id]) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [alert_overrides_alert_id] ON [ext].[alert_overrides] ([alert_id]) ON [PRIMARY]
GO
