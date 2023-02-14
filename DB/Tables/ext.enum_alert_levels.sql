CREATE TABLE [ext].[enum_alert_levels]
(
[level_id] [tinyint] NOT NULL,
[name] [nvarchar] (64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
) ON [PRIMARY]
GO
ALTER TABLE [ext].[enum_alert_levels] ADD CONSTRAINT [pk_enum_alert_levels] PRIMARY KEY CLUSTERED ([level_id]) ON [PRIMARY]
GO
