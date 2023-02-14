SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

create view [ext].[all_alerts]
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
			when ao.[override_audience] = 0 and ao.[audience] is not null then a.[audience] + ';' + ao.[audience]
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
		and (ao.[tag_name] is null and ao.[tag_value] is null and ao.[instance_id] is null);
GO
