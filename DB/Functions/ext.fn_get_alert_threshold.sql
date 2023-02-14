SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

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
GO
