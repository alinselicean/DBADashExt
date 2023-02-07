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
