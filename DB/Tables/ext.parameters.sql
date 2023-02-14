CREATE TABLE [ext].[parameters]
(
[id] [int] NOT NULL IDENTITY(1, 1),
[name] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[value] [nvarchar] (250) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
[description] [nvarchar] (max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL
) ON [PRIMARY]
GO
ALTER TABLE [ext].[parameters] ADD CONSTRAINT [pk_parameters] PRIMARY KEY CLUSTERED ([name]) ON [PRIMARY]
GO
