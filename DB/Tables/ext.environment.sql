CREATE TABLE [ext].[environment]
(
[id] [int] NOT NULL IDENTITY(1, 1),
[name] [nvarchar] (32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
[is_local] [bit] NOT NULL CONSTRAINT [df_environment_is_local] DEFAULT ((0))
) ON [PRIMARY]
GO
ALTER TABLE [ext].[environment] ADD CONSTRAINT [pk_environment] PRIMARY KEY CLUSTERED ([id]) ON [PRIMARY]
GO
