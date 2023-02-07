use [DBADashExt];
go

--drop table if exists [ext].[alert_history];
if object_id('[ext].[alert_history]') is null
begin
	create table [ext].[alert_history]
	(	[instance] varchar(128),
		[alert_id] int,
		[last_occurrence] datetime,
		[last_value] varchar(max),
		[status] varchar(32),

		constraint [pk_alert_history] primary key clustered
		(	[instance], [alert_id] )
	);
end;
