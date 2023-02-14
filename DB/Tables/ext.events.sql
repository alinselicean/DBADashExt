CREATE TABLE [ext].[events]
(
[event_id] [int] NOT NULL IDENTITY(1, 1),
[event_datetime] [datetime] NULL CONSTRAINT [df_events_event_datetime] DEFAULT (getutcdate()),
[event_source] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[event_type] [nvarchar] (100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[event_text] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
CREATE CLUSTERED INDEX [event_datetime] ON [ext].[events] ([event_datetime]) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [event_source] ON [ext].[events] ([event_source]) ON [PRIMARY]
GO
