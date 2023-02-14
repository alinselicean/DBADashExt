CREATE TABLE [ext].[alert_webhooks]
(
[id] [int] NOT NULL IDENTITY(1, 1),
[name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[type] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL CONSTRAINT [df_alert_webhooks_type] DEFAULT ('n/a'),
[environment] [int] NOT NULL,
[environment_name] [nvarchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[webhook] [varchar] (512) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[username] AS ('sql@cms-'+lower([environment_name])),
[webhook_id] AS (([environment_name]+'-')+replace([name],' ','')) PERSISTED
) ON [PRIMARY]
GO
ALTER TABLE [ext].[alert_webhooks] ADD CONSTRAINT [pk_alert_webhooks] PRIMARY KEY CLUSTERED ([id]) ON [PRIMARY]
GO
