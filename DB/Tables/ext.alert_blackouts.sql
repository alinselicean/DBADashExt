CREATE TABLE [ext].[alert_blackouts]
(
[blackout_id] [int] NOT NULL IDENTITY(1, 1),
[alert_id] [int] NOT NULL,
[day_of_week] [tinyint] NOT NULL,
[start_time] [time] NOT NULL,
[end_time] [time] NOT NULL,
[start_h] AS (datepart(hour,[start_time])) PERSISTED,
[start_m] AS (datepart(minute,[start_time])) PERSISTED,
[end_h] AS (datepart(hour,[end_time])) PERSISTED,
[end_m] AS (datepart(minute,[end_time])) PERSISTED
) ON [PRIMARY]
GO
ALTER TABLE [ext].[alert_blackouts] ADD CONSTRAINT [ck_alert_blackouts_day_of_week] CHECK (([day_of_week]>=(0) AND [day_of_week]<=(7)))
GO
ALTER TABLE [ext].[alert_blackouts] ADD CONSTRAINT [pk_alert_blackouts] PRIMARY KEY CLUSTERED ([blackout_id]) ON [PRIMARY]
GO
