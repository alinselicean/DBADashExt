use [master];

--drop database [DBADashExt];

if db_id('DBADashExt') is null
begin
	exec('create database [DBADashExt];');
end;

use [DBADashExt];
go

set nocount on;
/*
ext schema will contain all the extensions for alerting
*/
if schema_id('ext') is null exec('create schema [ext] authorization [dbo];');
if object_id('[ext].[events]') is null
begin
	create table [ext].[events]
	(	[event_id] [int] identity(1,1) not null,
		[event_datetime] [datetime] null,
		[event_source] [nvarchar](100) null,
		[event_type] [nvarchar](100) null,
		[event_text] [nvarchar](max) null
	);

	create clustered index [event_datetime] on [ext].[events]
	(
		[event_datetime] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
	);

	create nonclustered index [event_source] ON [ext].[events]
	(
		[event_source] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
	);
	alter table [ext].[events] add  constraint [df_events_event_datetime]  default (getutcdate()) for [event_datetime];
end;
if object_id('[ext].[parameters]') is null
begin
	create table [ext].[parameters]
	(	[id] [int] identity(1,1) not null,
		[name] [nvarchar](250) not null,
		[value] [nvarchar](250) null,
		[description] [nvarchar](max) null

	constraint [pk_parameters] primary key clustered 
	(
		[name] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
end;
if object_id('[ext].[enum_alert_levels]') is null
begin
	create table [ext].[enum_alert_levels]
	(	[level_id] [tinyint] not null,
		[name] [nvarchar](64) not null,
	 constraint [pk_enum_alert_levels] primary key clustered 
	(
		[level_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off,
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
end;
if object_id('[ext].[environment]') is null
begin
	create table [ext].[environment]
	(	[id] int identity(1,1),
		[name] [nvarchar](32) not null,
		[is_local] [bit] not null,
	constraint [pk_environment] primary key clustered 
	(
		[id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);

	alter table [ext].[environment] add  constraint [df_environment_is_local]  default ((0)) for [is_local]
end;
if object_id('[ext].[alerts]') is null
begin
	create table [ext].[alerts]
	(	[alert_id] [int] identity(1,1) not null,			-- id<0 = special alerts: template, custom & catch-all alerts
		[alert_name] [nvarchar](128) not null,
		[alert_env] int not null,
		[alert_wiki] [varchar](512) null,
		[repeat_notification_interval] [int] null,
		[escalation_interval] [int] null,					-- not used yet, future developments
		[last_notification] [datetime] null,
		[send_to_webhook] [bit] not null,
		[webhook_alert_template] [nvarchar](max) null,
		[email_alert_template] [nvarchar](max) null,
		[audience] [varchar](256) null,
		[alarm_emoji] [varchar](32) null,					-- provided defaults are specific to Slack
		[normal_emoji] [varchar](32) null,					-- provided defaults are specific to Slack
		[continue_emoji] [varchar](32) null,				-- provided defaults are specific to Slack
		[is_muted] [bit] not null,
		[default_threshold] varchar(max) null,

	constraint [PK_alerts] primary key clustered 
	(
		[alert_name] ASC,
		[alert_env] ASC
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);
	alter table [ext].[alerts] add  constraint [df_alerts_alert_env]  default ('internal') for [alert_env];
	alter table [ext].[alerts] add  constraint [df_alerts_send_to_webhook]  default ((0)) for [send_to_webhook];
	alter table [ext].[alerts] add  constraint [df_alerts_alarm_emoji]  default (',"icon_emoji": ":bell_red:"') for [alarm_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_normal_emoji]  default (',"icon_emoji": ":bell_green:"') for [normal_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_continue_emoji]  default (',"icon_emoji": ":bell_orange:"') for [continue_emoji];
	alter table [ext].[alerts] add  constraint [df_alerts_is_muted]  default ((0)) for [is_muted];
end;

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
if object_id('[ext].[alert_webhooks]') is null
begin
	create table [ext].[alert_webhooks]
	(	[id] [int] identity(1,1) not null,
		[name] nvarchar(128) not null,
		[type] varchar(128) not null constraint [df_alert_webhooks_type] default('n/a'),	/* can be Slack, Teams, etc */
		[environment] int not null,
		[webhook] [varchar](512) not null,
		[username]  as ('sql@cms-'+lower([environment])),
		[webhook_id] as [environment] + '-' + [name] persisted

	constraint [pk_alert_webhooks] primary key clustered 
	(
		[webhook_id]
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	)
end;
if object_id('[ext].[alert_overrides]') is null
begin
	create table [ext].[alert_overrides]
	(	[override_id] [int] identity(1,1) not null,
		[alert_id] [int] null,
		[webhook_alert_template] [nvarchar](max) null,
		[email_alert_template] [nvarchar](max) null,
		[alert_level] [tinyint] null,
		[audience] [varchar](256) null,
		[override_audience] [bit] not null,
		[emoji] [varchar](64) null,
		[webhook] varchar(512) null,
		[tag_name] nvarchar(50) null,
		[tag_value] nvarchar(128) null,
		[instance_id] int null,
		[threshold] varchar(max) null,

	constraint [pk_alert_overrides] primary key nonclustered 
	(
		[override_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);

	create clustered index [alert_overrides_alert_id] on [ext].[alert_overrides]
	(
		[alert_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = on, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		);
	alter table [ext].[alert_overrides] add constraint [df_alert_overrides_alert_level]  default ((1)) for [alert_level];
	alter table [ext].[alert_overrides] add constraint [df_alert_overrides_override_audience]  default ((0)) for [override_audience];
end;
if object_id('[ext].[alert_blackouts]') is null
begin
	create table [ext].[alert_blackouts]
	(	[blackout_id] [int] identity(1,1) not null,
		[alert_id] [int] not null,
		[day_of_week] [int] not null,
		[blackout_start_time] [varchar](8) not null,
		[blackout_end_time] [varchar](8) not null,
	constraint [pk_alert_blackouts] primary key nonclustered 
	(
		[blackout_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			ignore_dup_key = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		)
	);

	create clustered index [alert_id] on [ext].[alert_blackouts]
	(
		[alert_id] asc
	)
	with (	pad_index = off, 
			statistics_norecompute = off, 
			sort_in_tempdb = off, 
			drop_existing = off, 
			online = off, 
			allow_row_locks = on, 
			allow_page_locks = on
		);
end;
if object_id('[ext].[all_alerts]') is null
begin
exec('create view [ext].[all_alerts]
as
	select
		a.[alert_id] ,
		a.[alert_name],
		a.[alert_env],
		e.[name] as [environment],
		a.[alert_wiki],
		a.[repeat_notification_interval],
		a.[escalation_interval],
		a.[last_notification],
		a.[send_to_webhook],
		
		/* override templates, if any are specified */
		coalesce(ao.[webhook_alert_template],a.[webhook_alert_template]) as [webhook_alert_template],
		coalesce(ao.[email_alert_template],a.[email_alert_template]) as [email_alert_template],

		/* override audience if flag is set to 1 */
		case 
			when ao.[audience] is null then a.[audience]
			when ao.[override_audience] = 1 and ao.[audience] is not null then ao.[audience]
			when ao.[override_audience] = 0 and ao.[audience] is not null then a.[audience] + '';'' + ao.[audience]
			else a.[audience]
		end as [audience],

		coalesce(ao.[webhook], aw.[webhook]) as [webhook],

		/* override all emojis, if one is specified */
		coalesce(ao.[emoji], a.[alarm_emoji]) as [alarm_emoji],
		coalesce(ao.[emoji], a.[normal_emoji]) as [normal_emoji],
		coalesce(ao.[emoji], a.[continue_emoji]) as [continue_emoji],

		a.[is_muted],

		ao.[alert_level],
		eal.[name] as [alert_level_desc],
		ao.[override_audience],
		ao.[emoji],
		aw.[username]
	from [ext].[alerts] a
	inner join [ext].[environment] e on a.[alert_env] = e.[id] and e.[is_local] = 1
	left join [ext].[alert_overrides] ao on a.[alert_id] = ao.[alert_id]
	left join [ext].[enum_alert_levels] eal on ao.[alert_level] = eal.[level_id]
	left join [ext].[alert_webhooks] aw on a.[alert_env] = aw.[environment]
	where a.[alert_env] = (select [id] from [ext].[environment] where [is_local] = 1)
		/* exclude targeted overrides */
		and (ao.[tag_name] is null and ao.[tag_value] is null and ao.[instance_id] is null);');
end;

/* insert static data */
set identity_insert [ext].[environment] on;
insert into [ext].[environment]([id],[name],[is_local])
select src.[id],src.[name],src.[is_local]
from (
	-- add / remove entries as you need, only one environment can be local ([is_local] = 1)
	values	 (0,'*',0)
			,(1,'production',1)
			,(2,'internal',0)
			,(3,'stage',0)
	) src([id],[name],[is_local])
left join [ext].[environment] tgt on src.[name] = tgt.[name]
where tgt.[name] is null;
set identity_insert [ext].[environment] off;

insert into [ext].[enum_alert_levels]([level_id],[name])
select src.[level_id],src.[name]
from (
		-- do not change these
	values	 (0,'Normal')
			,(1,'Informational')
			,(2,'Warning')
			,(3,'Critical')
			,(4,'Fatal')
	) src([level_id],[name])
left join [ext].[enum_alert_levels] tgt on src.[level_id] = tgt.[level_id]
where tgt.[level_id] is null;

--truncate table [ext].[alerts];
set identity_insert [ext].[alerts] on;
;with src as 
(	select 
		a.[alert_id],
		a.[alert_name],
		a.[alert_env],
		a.[alert_wiki],
		a.[repeat_notification_interval],
		a.[escalation_interval],
		a.[last_notification],
		a.[send_to_webhook],
		a.[webhook_alert_template],
		a.[email_alert_template],
		a.[audience],
		a.[alarm_emoji],
		a.[normal_emoji],
		a.[continue_emoji],
		a.[is_muted],
		a.[default_threshold]
from (	
		values
			(	-2,'Template Alert',0,'http://url_to_alert_wiki',5,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				1, '{"text":"##ALERTNAME##: Alert text for ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
				'<html><body style="font-family:Tahoma;font-size:10pt;">Greetings<br/>This is the text for the alert detected for ##INSTANCES##. See the table below for more details.
		<br/><br/><table border="1" style="font-family:Tahoma;font-size:10pt">
		<tr>	
			<th>Column 1</th>
			<th>Column 2</th>
			<th>Column 3</th>
			<th>Column 4</th>
			<th>Column 5</th>
		</tr>
		##TABLE##
		</table>
		##WIKILINK##
		</body></html>','email@server.com',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,'10'
			),
			(	-1,'Catch-All',0,null,null,null,null,0,null,'<html><body style="font-family:Tahoma;font-size:10pt;">All<br/><br/>The alert notification SP has been invoked, but:<br/><ul>
<li>it reached this branch in error (check the logic in your code)</li>
<li>it has incorrect parameters and the call was converted into a Catch-All mode</li>
</ul><br/>
##PARAMS##
</body></html>','email@server.com',null,null,null,0,null),
			(	0,'Custom',0,null,null,null,null,0,null,null,null,null,null,null,0,null	),
/* 
actual alerts 
*/
			(	1,'Blocking - Duration',1,null,5,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: Excessive blocking detected on ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>Blocking on the instances listed below is exceeding the thresholds:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Sessions</th>
	<th>Wait Time (s)</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','youremail@domain.local',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,10000
			),
			(	2,'Blocking - Processes',1,null,5,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: Excessive blocking detected on ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>Blocking on the instances listed below is exceeding the thresholds:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Sessions</th>
	<th>Wait Time (s)</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','youremail@domain.local',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,2
			),
			(	3,'High CPU',1,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: High CPU on ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>CPU on the following instances is exceeding the thresholds:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Total CPU</th>
	<th>Threshold</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','youremail@domain.local',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,80
			),
			(	4,'High CPU - Recovery',1,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: CPU recovered on ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>CPU on the following instances recovered:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Total CPU</th>
	<th>Threshold</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','youremail@domain.local',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,null
			),
			(	5,'Disk Free Space',1,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: Some of the disks on the following instances are low on free space: ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>Some fo the disks on the following instances are low on free disk space:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Warning</th>
	<th>Critical</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','youremail@domain.local',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,null
			)
		) a([alert_id],[alert_name],[alert_env],[alert_wiki],[repeat_notification_interval],[escalation_interval],
			[last_notification],[send_to_webhook],[webhook_alert_template],[email_alert_template],[audience],[alarm_emoji],
			[normal_emoji],[continue_emoji],[is_muted],[default_threshold])
)
insert into [ext].[alerts]([alert_id],[alert_name],[alert_env],[alert_wiki],[repeat_notification_interval],[escalation_interval],
			[last_notification],[send_to_webhook],[webhook_alert_template],[email_alert_template],[audience],[alarm_emoji],
			[normal_emoji],[continue_emoji],[is_muted],[default_threshold])
select src.[alert_id],src.[alert_name],src.[alert_env],src.[alert_wiki],src.[repeat_notification_interval],src.[escalation_interval],
			src.[last_notification],src.[send_to_webhook],src.[webhook_alert_template],src.[email_alert_template],src.[audience],src.[alarm_emoji],
			src.[normal_emoji],src.[continue_emoji],src.[is_muted],src.[default_threshold]
from src
left join [ext].[alerts] tgt on src.[alert_name] = tgt.[alert_name] and src.[alert_env] = tgt.[alert_env]
where tgt.[alert_id] is null;
set identity_insert [ext].[alerts] off;

/* Insert sample blackout row */
-- blackout_id	alert_id	day_of_week	blackout_start_time	blackout_end_time
--1	3	-1	20:00:00	23:00:00
insert into [ext].[alert_blackouts]([alert_id],[day_of_week],[blackout_start_time],[blackout_end_time])
select src.[alert_id],src.[day_of_week],src.[blackout_start_time],src.[blackout_end_time]
from 
(	values
		(	-2, -1, '20:00:00','23:00:00')		-- -2 = template alert
) src([alert_id],[day_of_week],[blackout_start_time],[blackout_end_time])
left join [ext].[alert_blackouts] tgt on src.[alert_id] = tgt.[alert_id]
where tgt.[blackout_id] is null;

/* insert parameters */
--truncate table [ext].[parameters];
;with src as (	select p.[name],p.[value],p.[description]
				from (	
					-- add new params as you need
					values	 ('Alert/DBMailProfile','DBA Mail Profile','Database Mail profile to be used to send notifications')
							,('DBADash/DatabaseName','DBADashDB','The name of the DBADash repository database')
					) p([name],[value],[description])
				)
merge into [ext].[parameters] tgt 
using src on (src.[name] = tgt.[name])

when not matched by target then
	insert ([name],[value],[description])
	values (src.[name],src.[value],src.[description])
when matched and (src.[description] <> tgt.[description]) then
	update set [description] = src.[description]
;

/*
Insert actual alerts - template script. 
Expand the list with all the required alerts and associated details. 
Use this script as the main source for the alerts catalog, beyond the default alerts defined above
*/
/*
insert into [ext].[alerts]([alert_name],[alert_env],[alert_wiki],[repeat_notification_interval],[escalation_interval],
			[last_notification],[send_to_webhook],[webhook_alert_template],[email_alert_template],[audience],[alarm_emoji],
			[normal_emoji],[continue_emoji],[is_muted],[default_threshold])
select src.[alert_name],src.[alert_env],src.[alert_wiki],src.[repeat_notification_interval],src.[escalation_interval],
			src.[last_notification],src.[send_to_webhook],src.[webhook_alert_template],src.[email_alert_template],src.[audience],src.[alarm_emoji],
			src.[normal_emoji],src.[continue_emoji],src.[is_muted],src.[default_threshold]
from (
	values
			(	'change_me',1,null,5,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: <your_alert_text_here> for ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>Blocking on the instances listed below is exceeding the thresholds:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Sessions</th>
	<th>Wait Time (s)</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>','email@server.com',
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,10000
			)
	) src([alert_name],[alert_env],[alert_wiki],[repeat_notification_interval],[escalation_interval],
			[last_notification],[send_to_webhook],[webhook_alert_template],[email_alert_template],[audience],[alarm_emoji],
			[normal_emoji],[continue_emoji],[is_muted],[default_threshold])
left join [ext].[alerts] tgt on tgt.[alert_name] = src.[alert_name] and src.[alert_env] = tgt.[alert_env]
where tgt.[alert_id] is null;
go
*/
set ansi_nulls, quoted_identifier on
go

if object_id('[ext].[make_api_request]') is null exec('create PROCEDURE [ext].[make_api_request] as begin select 1 end;');
go
/*
Requires 'Ole Automation Procedures' advanced configuration enabled

sp_configure 'show advanced options', 1 
reconfigure with override; 

sp_configure 'Ole Automation Procedures', 1 
reconfigure with override; 

-- Need HTTPS in the outbound rules
-- open for hooks.slack.com (3.123.248.34)
*/
alter procedure [ext].[make_api_request]
(
	@RTYPE VARCHAR(MAX),
	@authHeader VARCHAR(MAX), 
	@RPAYLOAD VARCHAR(MAX), 
	@URL VARCHAR(MAX),
	@OUTSTATUS VARCHAR(MAX) OUTPUT,
	@OUTRESPONSE VARCHAR(MAX) OUTPUT
)
AS
BEGIN 
	DECLARE @contentType NVARCHAR(64);
	DECLARE @postData NVARCHAR(2000);
	DECLARE @responseText NVARCHAR(2000);
	DECLARE @responseXML NVARCHAR(2000);
	DECLARE @ret INT;
	DECLARE @status NVARCHAR(32);
	DECLARE @statusText NVARCHAR(32);
	DECLARE @token INT;

	SET @contentType = 'application/json';

	-- Open the connection.
	EXEC @ret = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	IF @ret <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @ret = sp_OAMethod @token, 'open', NULL, @RTYPE, @url, 'false';
	EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Authentication', @authHeader;
	EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', 'application/json';
	SET @RPAYLOAD = (SELECT CASE WHEN @RTYPE = 'Get' THEN NULL ELSE @RPAYLOAD END )
	EXEC @ret = sp_OAMethod @token, 'send', NULL, @RPAYLOAD; -- IF YOUR POSTING, CHANGE THE LAST NULL TO @postData

	-- Handle the response.
	EXEC @ret = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @ret = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	EXEC @ret = sp_OAGetProperty @token, 'responseText', @responseText OUT;

	-- Show the response.
	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	PRINT 'Response text: ' + @responseText;
	SET @OUTSTATUS = 'Status: ' + @status + ' (' + @statusText + ')'
	SET @OUTRESPONSE = 'Response text: ' + @responseText;

	-- Close the connection.
	EXEC @ret = sp_OADestroy @token;
	IF @ret <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);
END
go

if object_id('[ext].[send_alert_notification]') is null exec('create PROCEDURE [ext].[send_alert_notification] as begin select 1 end;');
go
alter procedure [ext].[send_alert_notification]
(
	@alert_name nvarchar(128) = 'custom',
	@alert_type tinyint = 255,					/* 255=custom, 0=normal, 1=alarm, 2=continue */
	@audience nvarchar(256) = null,				/* need @subj for alert_type = 255 */
	@email_template nvarchar(max) = null,		/* need @body for alert_type = 255 */
	@subj varchar(128) = null,					/* email subject */
	@alert_webhook nvarchar(512) = null,			/* slack webhook */
	@webhook_template nvarchar(max) = null,
	@emoji varchar(32) = null,
	@instances nvarchar(max) = null,
	@table nvarchar(max) = null,
	@bypass_mute bit = 0						/* bypass [is_muted] = 1 */
)
as
begin
	set nocount on;
	set datefirst 1;

	declare @env int = coalesce((select [id] from [ext].[environment] where [is_local] = 1),1);
	declare @emojis table([type] tinyint, [emoji] varchar(32));
	declare @dbmail_profile varchar(128) = (select [value] from [ext].[parameters] where [name] = 'Alert/DBMailProfile');

	/* alert variables */
	declare
		@send_to_webhook bit = 0,
		@last_notification datetime,
		@repeat_notification_interval int,
		@escalation_interval tinyint,
		@alarm_emoji varchar(32),
		@normal_emoji varchar(32),
		@continue_emoji varchar(32),
		@is_muted bit,
		@alert_level tinyint,
		@alert_level_desc varchar(64),
		@override_audience bit,
		@username varchar(128);
	declare @alert_wiki varchar(256) = null;
	declare @webhookresponse varchar(max);
	declare @webhookstatus varchar(max);
	declare @error bit = 0;
	declare @body varchar(max);

	declare @blackout_day int;
	declare @blackout_start_time varchar(8);
	declare @blackout_end_time varchar(8);

	/* check @alert_type for valid range values */
	if @alert_type not in (0, 1, 2, 255)
	begin
		raiserror('Invalid @alert_type parameter value (%i). Valid values: 0, 1, 2 and 255 (custom).', 10, 1, @alert_type) with nowait;
		set @error = 1;
	end;

	if @alert_type = 255 AND @alert_name <> 'Custom'
	begin
		raiserror('Specified @alert_name (%s) is incompatible with the specified @alert_type (%i)', 10, 1, @alert_name, @alert_type) with nowait;
		set @error = 1;
	end;

	/* Validate @alert_name when not custom */
	if @alert_name <> 'Custom' and not exists(select [alert_name] from [ext].[alerts] where [alert_name] = @alert_name)
	begin
		raiserror('Invalid @alert_name parameter value (%s) - alert is not defined in the [central].[alerts] table.', 10, 1, @alert_name) with nowait;
		set @error = 1;
	end;

	/* Check if at least one comm vector was supplied for custom alerting */
	if (@alert_name = 'Custom' or @alert_type = 255) and (@email_template is null and @webhook_template is null)
	begin
		raiserror('For custom alerts, at least one of the @email_template (for email alerts) or @webhook_template (for slack alerts) need to be supplied and none was supplied', 10, 1) with nowait;
		set @error = 1;
	end;

	/* Check if @audience was supplied if @email_template was supplied */
	if (@alert_name = 'Custom' or @alert_type = 255) and (@email_template is not null and @audience is null)
	begin
		raiserror('For a custom alert, when @email_template is supplied, @audience is also required, but none was supplied.', 10, 1) with nowait;
		SET @error = 1;
	end;

	/* Check if @email_template was supplied if @audience was supplied */
	if (@alert_name = 'Custom' or @alert_type = 255) and (@audience is not null and @email_template is null)
	begin
		raiserror('For a custom alert, when @audience is supplied, @email_template is also required, but none was supplied.', 10, 1) with nowait;
		set @error = 1;
	end;

	/* Check if @audience was supplied if @email_template was supplied */
	if (@alert_name = 'Custom' or @alert_type = 255) and (@webhook_template is not null and @alert_webhook is null)
	begin
		raiserror('For a custom alert, when @webhook_template is supplied, @alert_webhook is also required, but none was supplied. Disabling Slack alerting', 10, 1) with nowait;
		set @send_to_webhook = 0;
	end;

	/* Check if @email_template was supplied if @audience was supplied */
	if (@alert_name = 'Custom' or @alert_type = 255) and (@alert_webhook is not null and @webhook_template is null)
	begin
		raiserror('For a custom alert, when @alert_webhook is supplied, @webhook_template is also required, but none was supplied. Disabling Slack alerting', 10, 1) with nowait;
		set @send_to_webhook = 0;
	end;

	--if @alert_type <> 255 and 
	--	(	select [is_muted] 
	--		from [ext].all_alerts 
	--		where [alert_name] = @alert_name and ([alert_env] = 0 or [alert_env] = @env)) = 1
	--begin
	--	raiserror('Selected alert is muted. Skipping notifications', 10, 1) with nowait;
	--	set @error = 1;
	--end;

	if @dbmail_profile is null 
	begin
		/* no default mail profile exists in the config table, check if there's a default / public one */
		select @dbmail_profile = p.[name]
		from msdb.dbo.sysmail_principalprofile pp
		inner join msdb.dbo.sysmail_profile p on pp.[profile_id] = p.[profile_id]
		where pp.[is_default] = 1 or pp.[principal_sid] = 0x00;
	end;

	if @error = 0
	begin
		set @is_muted = 0;
		if @alert_type <> 255 and @alert_name <> 'Custom'
		begin
			/* not custom alert, get the metadata */
			select
				@send_to_webhook = aa.[send_to_webhook],
				@alert_wiki = aa.[alert_wiki],
				@last_notification = aa.[last_notification],
				@repeat_notification_interval = aa.[repeat_notification_interval],
				@escalation_interval = aa.[escalation_interval],
				@webhook_template = coalesce(@webhook_template,aa.[webhook_alert_template]),
				@email_template = coalesce(@email_template,aa.[email_alert_template]),
				@audience = coalesce(@audience,aa.[audience]),
				@alert_webhook = coalesce(@alert_webhook,aa.[webhook]),
				@alarm_emoji = aa.[alarm_emoji],
				@normal_emoji = aa.[normal_emoji],
				@continue_emoji = aa.[continue_emoji],
				@is_muted = CASE WHEN @bypass_mute = 1 THEN 0 ELSE aa.[is_muted] END,
				@alert_level = aa.[alert_level],
				@alert_level_desc = aa.[alert_level_desc],
				@override_audience = aa.[override_audience],
				@emoji = aa.[emoji],
				@username = aa.[username],

				@blackout_day = ab.[day_of_week],
				@blackout_start_time = ab.[blackout_start_time],
				@blackout_end_time = ab.[blackout_end_time]
			--SELECT *
			FROM [ext].[all_alerts] aa
			left join [ext].[alert_blackouts] ab on ab.[alert_id] = aa.[alert_id]
				where [alert_name] = @alert_name and ([alert_env] = 0 or [alert_env] = @env);
		end

		if @blackout_day is not null and @blackout_end_time is not null and @blackout_start_time is not null
		begin
			if (	@blackout_day = datepart(weekday, getdate()) or							/* specific day */
					@blackout_day = -1 or													/* ... any day */
					(@blackout_day = 0 and datepart(weekday, getdate()) between 1 and 5)	/* any weekday */
				)
				and getdate() between 
						convert(datetime, convert(varchar(10),datefromparts(year(getdate()), month(getdate()), day(getdate()))) + ' ' + @blackout_start_time) and 
						convert(datetime, convert(varchar(10),datefromparts(year(getdate()), month(getdate()), day(getdate()))) + ' ' + @blackout_end_time)
			begin
				/* alert was raised inside a blackout window, do not send anything */
				raiserror('INFO: [%s] alert raised inside a blackout window (from %s to %s)', 10, 1, @alert_name, @blackout_start_time, @blackout_end_time) with nowait;
				goto skip_alerting;
			end;
		end;

		/* disable webhook if something's missing */
		if @alert_webhook IS NULL OR (select [value_in_use] from sys.configurations where [name] = 'Ole Automation Procedures') <> 1 
			set @send_to_webhook = 0;

		if @send_to_webhook = 1 AND @webhook_template IS NULL 
			set @send_to_webhook = 0;

		set @instances = coalesce(@instances, 'not_specified');
		set @subj = coalesce(@subj, @alert_name + ' alert was raised');

		if @dbmail_profile is not null and @email_template is not null and @is_muted = 0
		begin
			set @body = @email_template;
			if @table is null
				set @body = replace(@body, '##TABLE##', replace(replace((	select 
																				td = [value], ''
																			from string_split(@instances,',') 
																			for xml path('tr')), '&gt;','>'), '&lt;','<'))
			else
				set @body = replace(@body, '##TABLE##', @table);

			set @body = replace(@body, '##WIKILINK##' , coalesce('Click <a href="' + @alert_wiki + '">here</a> for details and troubleshooting info',''));
			set @body = replace(@body, '##ALERTNAME##', coalesce(@alert_name,''));
			set @body = replace(@body, '##INSTANCES##', replace(replace((	select 
																			td = [value], ''
																		from string_split(@instances,',') 
																		for xml path('tr')), '&gt;','>'), '&lt;','<'));

			exec msdb.dbo.sp_send_dbmail
					@profile_name = @dbmail_profile,
					@recipients = @audience,
					@subject = @subj,
					@body = @body, 
					@body_format = 'HTML', 
					@importance = 'HIGH';
		end;
		/* send to webhook, if it's enabled and possible */
		if @send_to_webhook = 1 AND @is_muted = 0
		begin
			insert into @emojis([type], [emoji])
			values(0,@normal_emoji), (1,@alarm_emoji), (2,@continue_emoji);
			
			if @alert_type = 255
				insert into @emojis([type],[emoji]) values(@alert_type, @emoji);

			set @body = @webhook_template;
			set @body = replace(@body, '##WIKILINK##'	, coalesce('Click <' + @alert_wiki + '|here> for details and troubleshooting info',''));
			set @body = replace(@body, '##EMOJI##'		, coalesce(@emoji, (select [emoji] from @emojis where [type] = @alert_type),''));
			set @body = replace(@body, '##USERNAME##'	, coalesce(',"username": "' + @username + '"',''))
			set @body = replace(@body, '##INSTANCES##'	, coalesce(@instances,''))
			set @body = replace(@body, '##ALERTNAME##'	, coalesce(@alert_name,''));

			exec [ext].[make_api_request]
					@rtype = 'POST',
					@authHeader = '',
					@rpayload = @body,
					@url = @alert_webhook,
					@outStatus = @webhookStatus OUTPUT,
					@outResponse = @webhookResponse OUTPUT;
			
			if @webhookStatus <> 'Status: 200 (OK)'
			begin
				raiserror('WEBHOOK: Notification not delivered (status=%s; response=%s)', 10, 1, @webhookStatus, @webhookResponse) with nowait;
				raiserror('WEBHOOK: Payload: %s', 10, 1, @body) with nowait;

				insert into [ext].[events]([event_type], [event_source], [event_text])
				select 
					'ERROR', 
					OBJECT_NAME(@@PROCID), 
					'Error sending webhook notification for ' + @alert_name + '; Message: ' + @webhookResponse + '; Payload: ' + @body;
			end;
		end;
	end;		/* error = 0 */
skip_alerting:
end;
go

set quoted_identifier on;
go
if object_id('[ext].[alert_blocking]','P') is null exec('create procedure [ext].[alert_blocking] as begin select 1 end;');
go

alter procedure [ext].[alert_blocking]
(	 @alert_name varchar(128) = 'Blocking - Duration'
	,@tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@is_recursive_call bit = 0
	,@debug bit = 0
)
/*
Adapted from DBADash.com: 

https://dbadash.com/docs/help/alerts/
https://github.com/trimble-oss/dba-dash/blob/main/Docs/alert_samples/blocking.sql

The SP will check both criteria: Duration and Blocked Processes
*/
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	--declare 
	--	 @alert_name varchar(128) = 'Blocking - Duration'
	--	,@tagname nvarchar(50) = NULL
	--	,@tagvalue nvarchar(50) = NULL
	--	,@is_recursive_call bit = 0
	--	,@debug bit = 1;
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);

	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @err varchar(max);
	declare @result int;
	declare @table varchar(max);
	declare @delay int;
	declare @rows_debug int;

	declare @default_webhook varchar(256);
	declare @default_audience varchar(512);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);

	declare @webhook varchar(256);
	declare @audience varchar(512);
	declare @webhook_alert_template nvarchar(max);
	declare @email_alert_template nvarchar(max);

	declare @dynSQL nvarchar(4000);
	declare @cmd nvarchar(4000);
	declare @lastAlert datetime;
	declare @instances varchar(max);
	declare @rows int;
	declare @alert_date datetime = getdate();
	create table #blocking 
	(	Instance NVARCHAR(128) NOT NULL,
		InstanceID int,
		BlockedWaitTime BIGINT NOT NULL,
		BlockedSessionCount INT NOT NULL
	);

	if @debug = 1 raiserror('Checking / Raising [%s] alert',10,1,@alert_name) with nowait;
	set @dynSQL = N'use [##DBADASHDB##];
declare @tagid smallint=-1;
set	@err_OUT = 0;
set @rows_OUT = 0;
if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADASHDB##].dbo.Tags 
	where [TagName] = @p_TagName and [TagValue] = @p_TagValue;
	if @@rowcount=0
	begin
		set @err_OUT = -1;
		raiserror(''Tag not found'',11,1) with nowait;
	end
end;

if @err_OUT = 0
begin
	;with CurrentBlocking AS (
		select	i.[InstanceDisplayName],
				bss.[InstanceID],
				bss.[BlockedWaitTime],
				bss.[BlockedSessionCount],
				bss.[SnapshotDateUTC],
				row_number() over(partition by bss.[InstanceID] order by bss.[SnapshotDateUTC] DESC) rnum
		from dbo.BlockingSnapshotSummary BSS 
		join dbo.InstancesMatchingTags(@TagID) i on bss.[InstanceID] = I.[InstanceID]
		where bss.[SnapshotDateUTC] >= dateadd(mi,-3,getutcdate())
	)
	insert into #blocking([Instance],[InstanceID],[BlockedWaitTime], [BlockedSessionCount])
	SELECT	[InstanceDisplayName], 
			[InstanceID],
			[BlockedWaitTime],
			[BlockedSessionCount] 
	from CurrentBlocking
	where [rnum] = 1;
	set @rows_OUT = @@rowcount;
end;';

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	--if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @result = 0
	begin
		if @rows > 0
		begin
			select @delay = coalesce([repeat_notification_interval],0) from [ext].[alerts] where [alert_id] = @alert_id;
			if @debug = 1
			begin
				/* add few dummy rows to test with */
				insert into #Blocking values('SRV-DEMO1', 1, 1000000,100);
				insert into #Blocking values('SRV-DEMO2', 2, 1000000,100);
				insert into #Blocking values('SRV-DEMO3', 3, 1000000,100);
			end;
			if @debug = 1 
			begin
				/* delete instances that are within the "delay" window */
				select 'debug - @delay - to be deleted', @delay as [delay]
				select tgt.*
				from [ext].[alert_history] ah
				inner join #blocking tgt on tgt.[Instance] = ah.[instance]
				inner join [ext].[alerts] a on a.[alert_id] = ah.[alert_id]
				where ah.[alert_id] = @alert_id and ah.[last_occurrence] > dateadd(minute,-@delay,getdate());
			end;
			if @delay > 0
			begin
				/* remove instances that are inside the "delay" period */
				delete tgt
				from #Blocking tgt
				inner join [ext].[alert_history] ah on tgt.[Instance] = ah.[instance]
				inner join [ext].[alerts] a on a.[alert_id] = ah.[alert_id]
				where ah.[alert_id] = @alert_id and ah.[last_occurrence] > dateadd(minute,-@delay,getdate());

				set @rows_debug = @@rowcount;
			end;

			/* build the main blocking list */
			drop table if exists #blk;
			;with blk as 
			(	select b.*
					,cast([ext].fn_get_alert_threshold(@alert_id, @tagname, @tagvalue, b.[InstanceID]) as int) as [threshold]
				from #blocking b
			)
			select blk.* 
			into #blk
			from blk 
			where blk.[threshold] < case when @alert_name = 'Blocking - Duration' then blk.[BlockedWaitTime] else blk.[BlockedSessionCount] end;

			if @debug = 1
			begin
				select 'debug - #blk', * from #blk;
				select 'debug - #blk - history', * from [ext].[alert_history] where [alert_id] = @alert_id;
			end;
			if exists(select 1 from #blk)
			begin
				/* get the defaults first */
				select 
					@default_audience = a.[audience],
					@default_email_alert_template = a.[email_alert_template],
					@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
					@default_webhook_alert_template = a.[webhook_alert_template]
				from [ext].[alerts] a
				where a.[alert_id] = @alert_id;

				/* 
				Get the overrides, if defined. Order of precedence:
				1 (highest) = instance level overrides (instance_id <> NULL, tags = NULLs) - uses ext.alert_overrides
				2 (second) = tag level overrides (instance_id = NULL, tags <> NULLs) - uses ext.alert_overrides
				3 (last, fallback) = alert level definitions - from ext.alerts
				*/
				drop table if exists #ovr;
				with overrides as
				(	select distinct 1 as [precedence], b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from #blk b
					left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
					where ao.[alert_id] = @alert_id
						and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
					union all
					
					select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from [ext].[alert_overrides] ao 
					outer apply (select distinct [instanceid] from #blk) b([InstanceID])
					where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
						and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
					union all

					select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
						(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
						), a.[webhook_alert_template]
					from [ext].[alerts] a
					outer apply (select distinct [instanceid] from #blk) b([InstanceID])
					where a.[alert_id] = @alert_id 
				)
				, ovr as 
				(	select 
						row_number() over(partition by o.[instanceid] order by o.[precedence]) as rn,
						b.*, 
						coalesce(o.[audience], @default_audience) as [audience], 
						coalesce(o.[email_alert_template], @default_email_alert_template) as [email_alert_template], 
						coalesce(o.[webhook], @default_webhook) as [webhook], 
						coalesce(o.[webhook_alert_template], @default_webhook_alert_template) as [webhook_alert_template]
					from #blk b
					left join overrides o on b.[InstanceID] = o.[InstanceID]
				)
				select *
				into #ovr from ovr where [rn] = 1;

				/* build the driving list of distinct emails */
				drop table if exists #list;
				select distinct [audience], cast(0 as bit) as [done] into #list from #ovr;
				
				while 1=1
				begin
					select top 1 
						@audience = [audience]
					from #list where [done] = 0;
					if @@rowcount = 0 break;

					raiserror('Sending notifications for alert [%s] to [%s] recipients', 10, 1, @alert_name, @audience) with nowait;
					if @debug = 1
					begin
						select 'debug - merge', @audience, @alert_id as [alert_id], b.[instance], ovr.* 
						from #blk b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience

						select distinct 'debug - distinct notifications',
							@audience,
							ovr.[webhook],
							ovr.[webhook_alert_template],
							ovr.[email_alert_template]
						from #blk b
						inner join #ovr ovr on b.[instance] = ovr.[instance]
						inner join #list l on ovr.[audience] = l.[audience]
						where l.[audience] = @audience;
					end;

					/* build the message blocks required for the actual alert */
					set @table = (	select 
										td = b.[Instance], '', 
										td = format(b.[BlockedSessionCount],'N0'),'',
										td = format(b.[BlockedWaitTime]/1000.0,'N1'),''
									from #blk b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									for xml path('tr')
								);
					set @instances = stuff((select ',' + b.[Instance] 
											from #blk b
											inner join #ovr ovr on b.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
											order by b.[Instance] for xml path('')),1,1,'');

					select distinct
						@webhook = ovr.[webhook],
						@webhook_alert_template = ovr.[webhook_alert_template],
						@email_alert_template = ovr.[email_alert_template]
					from #blk b
					inner join #ovr ovr on b.[instance] = ovr.[instance]
					inner join #list l on ovr.[audience] = l.[audience]
					where l.[audience] = @audience;

					/* send the notification */
					exec [ext].[send_alert_notification] 
						@alert_name = @alert_name,
						@alert_type = 1,
						@table = @table,
						@instances = @instances,
						@alert_webhook = @webhook,
						@audience = @audience,
						@email_template = @email_alert_template,
						@webhook_template = @webhook_alert_template;

					/* update the [last_occurrence] column for the affected instances */
					merge into [ext].[alert_history] as tgt
					using (	select @alert_id as [alert_id], b.[instance] 
							from #blk b
							inner join #ovr ovr on b.[instance] = ovr.[instance]
							inner join #list l on ovr.[audience] = l.[audience]
							where l.[audience] = @audience) as src
						on (src.[instance] = tgt.[instance] and src.[alert_id] = tgt.[alert_id])
					when matched then
						update set tgt.[last_occurrence] = @alert_date
					when not matched by target then
						insert([instance],[alert_id],[last_occurrence])
						values(src.[instance],src.[alert_id], @alert_date);

					update #list set [done] = 1 where [audience] = @audience;
				end;
			end
			else
			begin
				raiserror('No significant blocking issues',10,1) with nowait;
			end;
		end
		else
		begin
			raiserror('No significant blocking issues',10,1) with nowait;
		end;
	end
	else
	begin
		raiserror('There was an error trying to raise the [%s] alert.', 10, 1, @alert_name) with nowait;
	end;

	if @is_recursive_call = 1 return;

	/* Now look for blocking -- number of blocked processes */
	if exists(	select 1 from [ext].[alerts] where [alert_name] = N'Blocking - Processes')
		exec [ext].[alert_blocking] @alert_name = 'Blocking - Processes', @tagname = @tagname, @tagvalue = @tagvalue, @is_recursive_call = 1, @debug = @debug;
end;
go

if object_id('[ext].[alert_cpu]','P') is null exec('create procedure [ext].[alert_cpu] as begin select 1 end;');
go

alter procedure [ext].[alert_cpu]
(	 @tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@debug bit = 0
)
as
begin
	set nocount on;
	--declare 	 
	--	 @tagname nvarchar(50) = NULL
	--	,@tagvalue nvarchar(50) = NULL
	--	,@debug bit = 1

	declare @alert_name nvarchar(128) = N'High CPU';
	declare @threshold int = coalesce((select [default_threshold] from [ext].[alerts] where [alert_name] = @alert_name),80);
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);
	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @alert_date datetime = getdate();
	declare @table_ON nvarchar(max);
	declare @instances_ON nvarchar(max);
	declare @table_OFF nvarchar(max);
	declare @instances_OFF nvarchar(max);
	declare @dynSQL nvarchar(4000);
	declare @cmd nvarchar(4000);
	declare @rows int;
	declare @result int;

	declare @default_webhook varchar(512);
	declare @default_audience varchar(256);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);

	declare @webhook varchar(512);
	declare @audience varchar(256);
	declare @webhook_alert_template nvarchar(max);
	declare @email_alert_template nvarchar(max);

	drop table if exists #results;
	drop table if exists #cpu;
	create table #results([alert_id] int, [Instance] nvarchar(128), [Counter] int, [InstanceID] int);
	set @dynSQL = N'use [##DBADashDB##];
declare @tagid smallint=-1;
declare @alert_id int = ##ALERT_ID##;

set	@err_OUT = 0;
set @rows_OUT = 0;

if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADASHDB##].dbo.Tags 
	where [TagName] = @p_TagName and [TagValue] = @p_TagValue;
	if @@rowcount=0
	begin
		set @err_OUT = -1;
		raiserror(''Tag not found'',11,1) with nowait;
	end
end;

if @err_OUT = 0
begin
	;with dates as 
	(	select [InstanceID], cast([SnapshotDate] as datetime2(3)) as [EventTime] 
		from [##DBADashDB##].dbo.CollectionDates where [Reference] = ''CPU''
	)
	, cte as 
	(	select 
			@alert_id as [alert_id], 
			ii.[InstanceDisplayName], 
			ii.[InstanceID],
			cpu.[TotalCPU] as [counter], 
			row_number() over(partition by cpu.[InstanceId] order by cpu.[EventTime] desc) as [rn]
	from [##DBADashDB##].dbo.CPU
	inner join [##DBADashDB##].dbo.InstancesMatchingTags(@TagID) i on cpu.[InstanceID] = I.[InstanceID]
	inner join dates d on d.[InstanceID] = cpu.[InstanceID] 
	inner join [##DBADashDB##].dbo.InstanceInfo ii on cpu.[InstanceID] = ii.[InstanceID]
	where cpu.[EventTime] >= dateadd(minute,-2,d.[EventTime]) and ii.[IsActive] = 1
	)
	select [alert_id], [InstanceDisplayName], [Counter], [InstanceID] from cte where [rn] = 1;
	set @rows_OUT = @@rowcount;
end;';
	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	set @cmd = replace(@cmd, '##ALERT_ID##', @alert_id);	

	insert into #results([alert_id], [Instance], [Counter], [InstanceID])
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @rows > 0
	begin
		;with th as 
		(select 
			cpu.*,
			cast([ext].[fn_get_alert_threshold](cpu.[alert_id], @tagName, @tagValue, cpu.[InstanceID]) as int) as [threshold]
		from #results cpu
		)
		select
			th.*
			,ah.[status]
			,cast(
			case 
				-- instance is not in the history and is above threshold ==> add it and set alarm status to ON
				when ah.[alert_id] is null and th.[Counter] >= th.[threshold] then 'NEW->ON'
				-- instance is not in the history and is below threshold ==> ignore it
				when ah.[alert_id] is null and th.[Counter] < th.[threshold] then 'IGNORE'
				-- instance is in the history, alarm state is ON AND cpu is less than the threshold ==> switch the alarm state to OFF
				when ah.[alert_id] is not null and ah.[status] = 'ON' and th.[Counter] < th.[threshold] then 'ON->OFF'
				-- instance is in the history, alarm state is ON AND cpu is still greater than the threshold ==> ignore it
				when ah.[alert_id] is not null and ah.[status] = 'ON' and th.[Counter] >= th.[threshold] then 'IGNORE'
				-- instance is in the history, alarm state is OFF AND cpu is greater than the threshold ==> switch the alarm state to ON
				when ah.[alert_id] is not null and ah.[status] = 'OFF' and th.[Counter] >= th.[threshold] then 'OFF->ON'
				-- instance is in the history, alarm state is OFF AND cpu is less than the threshold ==> ignore it
				when ah.[alert_id] is not null and ah.[status] = 'OFF' and th.[Counter] < th.[threshold] then 'IGNORE'
			end as varchar(20)) as [action]	
		into #cpu
		-- #results + [threshold] + [status] + [action]
		from th  
		left join [ext].[alert_history] ah on th.[alert_id] = ah.[alert_id] and th.[Instance] = ah.[instance];

		if @debug = 1
		begin
			/* add few dummy rows to test with */
			-- [alert_id], [TotalCPU], [SQLProcessCPU], [Instance], [InstanceID], [threshold], [status], [action]
			insert into #cpu values(3, 35,1,'SRV-DEMO01',1,10,'OFF','OFF->ON');
			insert into #cpu values(3, 55,1,'SRV-DEMO02',2,10,'OFF','OFF->ON');
			insert into #cpu values(3, 83,1,'SRV-DEMO03',3,10,'OFF','OFF->ON');
		end;

		/* get the defaults first */
		select 
			@default_audience = a.[audience],
			@default_email_alert_template = a.[email_alert_template],
			@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
			@default_webhook_alert_template = a.[webhook_alert_template]
		from [ext].[alerts] a
		where a.[alert_id] = @alert_id;

		/* 
		Get the overrides, if defined. Order of precedence:
		1 (highest) = instance level overrides (instance_id <> NULL, tags = NULLs) - uses ext.alert_overrides
		2 (second) = tag level overrides (instance_id = NULL, tags <> NULLs) - uses ext.alert_overrides
		3 (last, fallback) = alert level definitions - from ext.alerts
		*/
		drop table if exists #ovr;
		with overrides as
		(	select distinct 1 as [precedence], b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
			from #cpu b
			left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
			where ao.[alert_id] = @alert_id
				and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
			union all
					
			select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
			from [ext].[alert_overrides] ao 
			outer apply (select distinct [instanceid] from #cpu) b([InstanceID])
			where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
				and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
			union all

			select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
				(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
				), a.[webhook_alert_template]
			from [ext].[alerts] a
			outer apply (select distinct [instanceid] from #cpu) b([InstanceID])
			where a.[alert_id] = @alert_id 
		)
		, ovr as 
		(	select 
				row_number() over(partition by o.[instanceid] order by o.[precedence]) as rn,
				b.*, 
				coalesce(o.[audience], @default_audience) as [audience], 
				coalesce(o.[email_alert_template], @default_email_alert_template) as [email_alert_template], 
				coalesce(o.[webhook], @default_webhook) as [webhook], 
				coalesce(o.[webhook_alert_template], @default_webhook_alert_template) as [webhook_alert_template]
			from #cpu b
			left join overrides o on b.[InstanceID] = o.[InstanceID]
		)
		select *
		into #ovr from ovr where [rn] = 1;

		/* build the driving list of distinct emails */
		drop table if exists #list;
		select distinct [audience], cast(0 as bit) as [done] into #list from #ovr;
				
		while 1=1
		begin
			select top 1 
				@audience = [audience]
			from #list where [done] = 0;
			if @@rowcount = 0 break;

			raiserror('Sending notifications for alert [%s] to [%s] recipients', 10, 1, @alert_name, @audience) with nowait;
			if @debug = 1
			begin
				select 'debug - merge', @audience, @alert_id as [alert_id], b.[instance], ovr.* 
				from #cpu b
				inner join #ovr ovr on b.[instance] = ovr.[instance]
				inner join #list l on ovr.[audience] = l.[audience]
				where l.[audience] = @audience

				select distinct 'debug - distinct notifications',
					@audience,
					ovr.[webhook],
					ovr.[webhook_alert_template],
					ovr.[email_alert_template]
				from #cpu b
				inner join #ovr ovr on b.[instance] = ovr.[instance]
				inner join #list l on ovr.[audience] = l.[audience]
				where l.[audience] = @audience;
			end;

			/* process the results */
			/* get the instances that are going ON (High CPU) */
			set @instances_ON = stuff((	select ',' + cpu.[Instance]
										from #cpu cpu
										inner join #ovr ovr on cpu.[instance] = ovr.[instance]
										inner join #list l on ovr.[audience] = l.[audience]
										where l.[audience] = @audience
											and cpu.[action] in ('NEW->ON','OFF->ON')
										order by cpu.[Instance]
										for xml path('')
								),1,1,'');
			set @table_ON = (	select 
									td = cpu.[Instance],'',
									td = cpu.[Counter], '',
									td = cpu.[threshold], ''
								from #cpu cpu
								inner join #ovr ovr on cpu.[instance] = ovr.[instance]
								inner join #list l on ovr.[audience] = l.[audience]
								where l.[audience] = @audience
									and cpu.[action] in ('NEW->ON','OFF->ON')
								order by cpu.[Instance]
								for xml path('tr')
							);

			/* get the instances that are going OFF (CPU recovered) */
			set @instances_OFF = stuff((	select ',' + cpu.[Instance]
											from #cpu cpu
											inner join #ovr ovr on cpu.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
												and cpu.[action] = 'ON->OFF'
											order by cpu.[Instance]
											for xml path('')
									),1,1,'');
			set @table_OFF = (	select
									td = cpu.[Instance],'',
									td = cpu.[Counter], '',
									td = cpu.[threshold], ''
								from #cpu cpu
								inner join #ovr ovr on cpu.[instance] = ovr.[instance]
								inner join #list l on ovr.[audience] = l.[audience]
								where l.[audience] = @audience
									and cpu.[action] = 'ON->OFF'
								order by cpu.[Instance]
								for xml path('tr')
							);

			/* get the specific comm settings */
			select distinct
				@webhook = ovr.[webhook],
				@webhook_alert_template = ovr.[webhook_alert_template],
				@email_alert_template = ovr.[email_alert_template]
			from #cpu b
			inner join #ovr ovr on b.[instance] = ovr.[instance]
			inner join #list l on ovr.[audience] = l.[audience]
			where l.[audience] = @audience;

			/* good news first... send the recovery notifications */
			if @table_OFF is not null
			begin
				set @alert_name = 'High CPU - Recovery';
				raiserror('[%s]: Instances: %s; Table: %s',10,1,@alert_name, @instances_OFF, @table_OFF) with nowait;
				exec [ext].[send_alert_notification] 
					@alert_name = @alert_name,
					@alert_type = 0,
					@table = @table_OFF,
					@instances = @instances_OFF,
					@audience = @audience,
					@alert_webhook = @webhook,
					@email_template = @email_alert_template,
					@webhook_template = @webhook_alert_template;
			end;

			/* ...and now with the bad news */
			if @table_ON is not null
			begin
				set @alert_name = 'High CPU';
				raiserror('[%s]: Instances: %s; Table: %s',10,1,@alert_name, @instances_ON, @table_ON) with nowait;
				exec [ext].[send_alert_notification] 
					@alert_name = @alert_name,
					@alert_type = 0,
					@table = @table_ON,
					@instances = @instances_ON,
					@audience = @audience,
					@alert_webhook = @webhook,
					@email_template = @email_alert_template,
					@webhook_template = @webhook_alert_template;
			end;

			update #list set [done] = 1 where [audience] = @audience;
		end;

		if exists(	select 1 from #cpu where [action] <> 'IGNORE')
		begin
			/* record statuses */
			insert into [ext].[alert_history]([alert_id],[instance],[last_occurrence],[last_value],[status])
			select cpu.[alert_id], cpu.[Instance],@alert_date,cpu.[Counter],'ON'
			from #cpu cpu 
			where cpu.[action] = 'NEW->ON';

			update tgt
				set [last_value] = cpu.[Counter], 
					[last_occurrence] = @alert_date,
					[status] = case when cpu.[action] = 'ON->OFF' then 'OFF' else 'ON' end
			from #cpu cpu
			inner join [ext].[alert_history] tgt on tgt.[alert_id] = cpu.[alert_id] and tgt.[instance] = cpu.[Instance]
			where cpu.[action] in ('OFF->ON', 'ON->OFF');
		end
		else
		begin
			raiserror('No change',10,1) with nowait;
		end;
	end;
end;
go

if object_id (N'[ext].[fn_get_alert_threshold]') is not null
   drop function [ext].[fn_get_alert_threshold];
go

create function [ext].[fn_get_alert_threshold]
(	@alert_id int = 1, 
	@tagname nvarchar(50) = NULL, 
	@tagvalue nvarchar(128) = NULL, 
	@instance_id int = 1
)
returns 
	varchar(max)
	with execute as owner
as
begin
	declare @result varchar(max);
	/* 
	order of precedence:
		- instanceid level thresholds comes first, if defined
		- tagname / tagvalue level thresholds comes next, if defined
		- fallbacks to the default threshold if none of the above is defined
	*/
	;with th([rank], [alert_id],[threshold]) as
	(	select 1,[alert_id],[threshold]
		from [ext].[alert_overrides] 
		where [alert_id] = @alert_id and ([tag_name] is null and [tag_value] is null) and [instance_id] = @instance_id
		union all

		select 2,[alert_id],[threshold]
		from [ext].[alert_overrides] 
		where [alert_id] = @alert_id and ([tag_name] = @tagname and [tag_value] = @tagvalue) and [instance_id] is null
		union all

		select 3,[alert_id],[default_threshold]
		from [ext].[alerts] 
		where [alert_id] = @alert_id
	) 
	, res as
	(	select *,
			row_number() over(order by [rank] asc) [rn]
		from th
	)
	select @result = [threshold] from res where [rn] = 1;
	return @result;
end
go


if object_id('[ext].[alert_freespace]','P') is null exec('create procedure [ext].[alert_freespace] as begin select 1 end;');
go

alter procedure [ext].[alert_freespace]
(	 @alert_name varchar(128) = 'Disk Free Space'
	,@tagname nvarchar(50) = NULL
	,@tagvalue nvarchar(50) = NULL
	,@is_recursive_call bit = 0
	,@debug bit = 0
)
/*
The SP will check both criteria: Long running queries and Blocked Processes
*/
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	--declare 
	--	 @alert_name varchar(128) = 'Queries - Long Duration'
	--	,@tagname nvarchar(50) = NULL
	--	,@tagvalue nvarchar(50) = NULL
	--	,@is_recursive_call bit = 0
	--	,@debug bit = 1;
	declare @alert_id int = (select [alert_id] from [ext].[alerts] where [alert_name] = @alert_name);

	/* Get the DBADash repository database name - if no record exists, it defaults to DBADashDB */
	declare @DBADashDB varchar(128) = coalesce((select [value] from [ext].[parameters] where [name] = 'DBADash/DatabaseName'), 
										'DBADashDB');
	declare @err varchar(max);
	declare @result int;
	declare @table varchar(max);
	declare @delay int;
	declare @rows_debug int;

	declare @default_webhook varchar(256);
	declare @default_audience varchar(512);
	declare @default_webhook_alert_template nvarchar(max);
	declare @default_email_alert_template nvarchar(max);

	declare @webhook varchar(256);
	declare @audience varchar(512);
	declare @webhook_alert_template nvarchar(max);
	declare @email_alert_template nvarchar(max);

	declare @dynSQL nvarchar(4000);
	declare @cmd nvarchar(4000);
	declare @lastAlert datetime;
	declare @instances varchar(max);
	declare @rows int;
	declare @alert_date datetime = getdate();

	if @debug = 1 raiserror('Checking / Raising [%s] alert',10,1,@alert_name) with nowait;
	create table #results([alert_id] int, [Instance] nvarchar(128), [InstanceID] int, [DrivesInCritical] int, [DrivesInWarning] int);
	set @dynSQL = N'use [##DBADashDB##];
declare @tagid smallint=-1;
set	@err_OUT = 0;
set @rows_OUT = 0;
if @p_tagname is not null and @p_tagvalue is not null
begin
	select @tagid = [TagId] from [##DBADashDB##].dbo.Tags 
	where [TagName] = @p_TagName and [TagValue] = @p_TagValue;
	if @@rowcount=0
	begin
		set @err_OUT = -1;
		raiserror(''Tag not found'',11,1) with nowait;
	end
end;

if @err_OUT = 0
begin
	;with dates as 
	(	select [InstanceID], cast([SnapshotDate] as datetime2(3)) as [SnapshotDateUtc] 
		from [##DBADashDB##].dbo.CollectionDates where [Reference] = ''Drives''
	)
	, cte as 
	(	select 
			@alert_id as [alert_id], 
			src.[InstanceDisplayName], 
			src.[InstanceID],
			sum(case when src.[PctFreeSpace] < src.[DriveCriticalThreshold] then 1 else 0 end) as [DrivesInCritical],
			sum(case when src.[PctFreeSpace] < src.[DriveWarningThreshold] then 1 else 0 end) as [DrivesInWarning]
	from [##DBADashDB##].dbo.DriveStatus src
	inner join [##DBADashDB##].dbo.InstancesMatchingTags(@TagID) i on src.[InstanceID] = I.[InstanceID]
	inner join dates d on d.[InstanceID] = src.[InstanceID] and d.[SnapshotDateUtc] = src.[SnapshotDate]
	inner join [##DBADashDB##].dbo.InstanceInfo ii on src.[InstanceID] = ii.[InstanceID]
	where ii.[IsActive] = 1
	group by src.[InstanceDisplayName], src.[InstanceID]
	)
	insert into #results([alert_id], [Instance], [InstanceID], [DrivesInCritical], [DrivesInWarning])
	select [alert_id], [InstanceDisplayName], [InstanceID], [DrivesInCritical], [DrivesInWarning] from cte
	where [DrivesInCritical] + [DrivesInWarning] > 0;
	set @rows_OUT = @@rowcount;
end;';

	set @cmd = @dynSQL;
	set @cmd = replace(@cmd, '##DBADASHDB##', @DBADashDB);
	if @debug = 1 select 'debug - @dynSQL', cast('<?q-- ' + @cmd + ' --?>' as xml) as [dynSQL];
	exec sp_executesql @stmt = @cmd, 
		@params = N'@p_TagName nvarchar(50), @p_TagValue nvarchar(50), @alert_id int, @err_OUT int OUTPUT, @rows_OUT int OUTPUT',
		@alert_id = @alert_id,
		@p_TagName = @tagname,
		@p_TagValue = @tagvalue,
		@err_OUT = @result OUTPUT,
		@rows_OUT = @rows OUTPUT;

	if @debug = 1 set @rows = 1;
	if @result = 0
	begin
		if @rows > 0
		begin
			/* build the main blocking list */
			drop table if exists #drv;
			;with drv as 
			(	select b.*
					,cast([ext].fn_get_alert_threshold(@alert_id, @tagname, @tagvalue, b.[InstanceID]) as int) as [threshold]
				from #results b
			)
			select drv.* into #drv from drv;

			if exists(select 1 from #drv)
			begin
				/* get the defaults first */
				select 
					@default_audience = a.[audience],
					@default_email_alert_template = a.[email_alert_template],
					@default_webhook = (select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]),
					@default_webhook_alert_template = a.[webhook_alert_template]
				from [ext].[alerts] a
				where a.[alert_id] = @alert_id;

				/* 
				Get the overrides, if defined. Order of precedence:
				1 (highest) = instance level overrides (instance_id <> NULL, tags = NULLs) - uses ext.alert_overrides
				2 (second) = tag level overrides (instance_id = NULL, tags <> NULLs) - uses ext.alert_overrides
				3 (last, fallback) = alert level definitions - from ext.alerts
				*/
				drop table if exists #ovr;
				with overrides as
				(	select distinct 1 as [precedence], b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from #drv b
					left join [ext].[alert_overrides] ao on ao.[instance_id] = b.[InstanceID]
					where ao.[alert_id] = @alert_id
						and ([tag_name] is null and [tag_value] is null and ao.[instance_id] is not null)
					union all
					
					select distinct 2, b.[InstanceID], ao.[audience], ao.[email_alert_template], ao.[webhook], ao.[webhook_alert_template]
					from [ext].[alert_overrides] ao 
					outer apply (select distinct [instanceid] from #drv) b([InstanceID])
					where ao.[alert_id] = @alert_id and ao.[tag_name] = @tagname and ao.[tag_value] = @tagvalue
						and ([tag_name] is not null and [tag_value] is not null and ao.[instance_id] is null)
					union all

					select distinct 3, b.[InstanceID], a.[audience], a.[email_alert_template], 
						(select [webhook] from [ext].[alert_webhooks] aw where aw.[environment] = a.[alert_env]
						), a.[webhook_alert_template]
					from [ext].[alerts] a
					outer apply (select distinct [instanceid] from #drv) b([InstanceID])
					where a.[alert_id] = @alert_id 
				)
				, ovr as 
				(	select 
						row_number() over(partition by o.[instanceid] order by o.[precedence]) as rn,
						b.*, 
						coalesce(o.[audience], @default_audience) as [audience], 
						coalesce(o.[email_alert_template], @default_email_alert_template) as [email_alert_template], 
						coalesce(o.[webhook], @default_webhook) as [webhook], 
						coalesce(o.[webhook_alert_template], @default_webhook_alert_template) as [webhook_alert_template]
					from #drv b
					left join overrides o on b.[InstanceID] = o.[InstanceID]
				)
				select *
				into #ovr from ovr where [rn] = 1;

				/* build the driving list of distinct emails */
				drop table if exists #list;
				select distinct [audience], cast(0 as bit) as [done] into #list from #ovr;
				
				while 1=1
				begin
					select top 1 
						@audience = [audience]
					from #list where [done] = 0;
					if @@rowcount = 0 break;

					raiserror('Sending notifications for alert [%s] to [%s] recipients', 10, 1, @alert_name, @audience) with nowait;

					/* build the message blocks required for the actual alert */
					set @table = (	select 
										td = b.[Instance], '', 
										td = format(b.[DrivesInWarning],'N0'),'',
										td = format(b.[DrivesInCritical],'N0'),''
									from #drv b
									inner join #ovr ovr on b.[instance] = ovr.[instance]
									inner join #list l on ovr.[audience] = l.[audience]
									where l.[audience] = @audience
									for xml path('tr')
								);
					set @instances = stuff((select ',' + b.[Instance] 
											from #drv b
											inner join #ovr ovr on b.[instance] = ovr.[instance]
											inner join #list l on ovr.[audience] = l.[audience]
											where l.[audience] = @audience
											order by b.[Instance] for xml path('')),1,1,'');

					select distinct
						@webhook = ovr.[webhook],
						@webhook_alert_template = ovr.[webhook_alert_template],
						@email_alert_template = ovr.[email_alert_template]
					from #drv b
					inner join #ovr ovr on b.[instance] = ovr.[instance]
					inner join #list l on ovr.[audience] = l.[audience]
					where l.[audience] = @audience;

					/* send the notification */
					exec [ext].[send_alert_notification] 
						@alert_name = @alert_name,
						@alert_type = 1,
						@table = @table,
						@instances = @instances,
						@alert_webhook = @webhook,
						@audience = @audience,
						@email_template = @email_alert_template,
						@webhook_template = @webhook_alert_template;

					/* update the [last_occurrence] column for the affected instances */
					merge into [ext].[alert_history] as tgt
					using (	select @alert_id as [alert_id], b.[instance] 
							from #drv b
							inner join #ovr ovr on b.[instance] = ovr.[instance]
							inner join #list l on ovr.[audience] = l.[audience]
							where l.[audience] = @audience) as src
						on (src.[instance] = tgt.[instance] and src.[alert_id] = tgt.[alert_id])
					when matched then
						update set tgt.[last_occurrence] = @alert_date
					when not matched by target then
						insert([instance],[alert_id],[last_occurrence])
						values(src.[instance],src.[alert_id], @alert_date);

					update #list set [done] = 1 where [audience] = @audience;
				end;
			end
			else
			begin
				raiserror('Drives OK',10,1) with nowait;
			end;
		end
		else
		begin
			raiserror('Drives OK',10,1) with nowait;
		end;
	end
	else
	begin
		raiserror('There was an error trying to raise the [%s] alert.', 10, 1, @alert_name) with nowait;
	end;
end;
go
