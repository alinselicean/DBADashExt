use [DBADashExt];
go

declare @your_email varchar(256) = 'sqlalert@rtc.ro';
declare @alert_env int = coalesce((select [id] from ext.environment where [is_local] = 1),1);

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
			(	-2,'Template Alert',@alert_env,'http://url_to_alert_wiki',5,null,'1900-01-01 00:00:00.000',
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
			(	1,'Blocking - Duration',@alert_env,null,5,null,'1900-01-01 00:00:00.000',
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
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,'10000'
			),
			(	2,'Blocking - Processes',@alert_env,null,5,null,'1900-01-01 00:00:00.000',
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
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,'2'
			),
			(	3,'High CPU',@alert_env,null,0,null,'1900-01-01 00:00:00.000',
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
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,'80'
			),
			(	4,'High CPU - Recovery',@alert_env,null,0,null,'1900-01-01 00:00:00.000',
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
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,null
			),
			(	5,'Disk Free Space',@alert_env,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: Some of the disks on the following instances are low on free space: ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>Some fo the disks on the following instances are low on free disk space:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance name</th>
	<th>Warning</th>
	<th>Drive details (warning)</th>
	<th>Critical</th>
	<th>Drive details (critical)</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,null
			)
			,(	6,'DB Growths',@alert_env,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, '{"text":"##ALERTNAME##: One or more databases on the following instances have grown since last check: ##INSTANCES##. ##WIKILINK##"##EMOJI####USERNAME##}',
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>One or more databases on the following instances have grown since last check:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Instance</th>	
	<th>Database</th>
	<th>File</th>
	<th>Size MB</th>
	<th>Total Growth MB</th>
	<th>Is % Growth</th>
	<th>AutoGrowth Pct</th>
	<th>AutoGrowth MB</th>
	<th>AutoGrow Count</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,null
			)
			,(	7,'Top Head Blockers',@alert_env,null,0,null,'1900-01-01 00:00:00.000',
				-- webhook details (specific for Slack)
				0, null,
				-- email section
'<html><body style="font-face:Tahoma;font-size:10pt">All<br/>These are the top blockers since last check:<br/>
<table border="1" style="font-family:Tahoma;font-size:10pt">
<tr>
	<th>Rank</th> 
	<th>Instance</th> 
	<th>SQL Handle</th> 
	<th>Occurrences</th> 
	<th>Total Block Count / Wait Time (s)</th>
	<th>Total Block Count Recursive / Wait Time (s)</th> 
	<th>Avg Duration (ms)</th>
	<th>Query</th>
	<th>Additional Info</th>
</tr>
##TABLE##
</table>
##WIKILINK##
</body></html>',@your_email,
				-- webhook emojis (values are specific to Slack - check the specs for other platforms)
				',"icon_emoji": ":bell_red:"',
				',"icon_emoji": ":bell_green:"',
				',"icon_emoji": ":bell_orange:"',
				0,'@MinutesBack int=15,@MinBlockWaitTimeRecursive int=10000'
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
