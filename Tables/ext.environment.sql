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
