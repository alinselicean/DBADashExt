CREATE TABLE [ext].[alert_history]
(
[instance] [varchar] (128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[alert_id] [int] NOT NULL,
[last_occurrence] [datetime] NULL,
[last_value] [varchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[status] [varchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [ext].[alert_history] ADD CONSTRAINT [pk_alert_history] PRIMARY KEY CLUSTERED ([instance], [alert_id]) ON [PRIMARY]
GO
