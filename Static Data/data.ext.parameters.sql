use [DBADashExt];
go

/* insert parameters */
--truncate table [ext].[parameters];
;with src as (	select p.[name],p.[value],p.[description]
				from (	
					-- add new params as you need
					values	 ('Alert/DBMailProfile','DBA Mail Profile','Database Mail profile to be used to send notifications')
							,('DBADash/DatabaseName','DBADashDB','The name of the DBADash repository database')
							,('Reports/TopBlockers/MinBlockedWaitTimeMs', '10000', 'The wait time (in milliseconds) threshold for top blockers')
							,('Reports/TopBlockers/TopNRows', '10', 'The number of top blockers to be included in the report. The alert will use a hard coded value of 5')
							,('Reports/TopBlockers/IncludeWithAlert', '0', 'Include the Top Head Blockers report as part of the alert')
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
