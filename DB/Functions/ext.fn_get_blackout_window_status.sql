SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO

create function [ext].[fn_get_blackout_window_status]
(	@alert_date datetime = null,
	@alert_id int
)
returns bit
	with execute as owner
as
begin
	declare @isInsideBlackoutWindow bit = 0;
	declare @days table([dayCode] int, [day] varchar(32));

	declare @now datetime = coalesce(@alert_date,getdate());
	declare @now_h int = datepart(hour, @now), @now_m int = datepart(minute, @now);
	declare @day nvarchar(32) = datename(dw, @now);

	insert into @days([dayCode], [day])
	values
		 (1,'Monday'	)
		,(2,'Tuesday'	)
		,(3,'Wednesday'	)
		,(4,'Thursday'	)
		,(5,'Friday'	)
		,(6,'Saturday'	)
		,(7,'Sunday'	);

	if exists(	select 1 from [ext].alert_blackouts where [alert_id] = @alert_id)
	begin
		select @isInsideBlackoutWindow = 
			case 
				when (	(@now_h = bo.[start_h] and @now_m >= bo.[start_m])
					or	(@now_h > bo.[start_h] and (	@now_h < bo.[end_h] 
													or (@now_h = bo.[end_h] and @now_m <= bo.[end_m])
												)
						)	
					) then 1
				else 0
			end
		from [ext].[alert_blackouts] bo
		where	bo.[alert_id] = @alert_id 
			and (bo.[day_of_week] = 0 or bo.[day_of_week] = (select d.[dayCode] from @days d where d.[day] = @day))
			and @now_h between bo.[start_h] and bo.[end_h];
	end;
	return @isInsideBlackoutWindow;
end;
GO
