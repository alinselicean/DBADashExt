use [DBADashExt];
go

set ansi_nulls, quoted_identifier on
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
