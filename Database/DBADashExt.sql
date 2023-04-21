use [master];

/* if you need to redeploy everything, uncomment next line */
--drop database [DBADashExt];

if db_id('DBADashExt') is null
begin
	exec('create database [DBADashExt] collate SQL_Latin1_General_CP1_CI_AS;');
end;
