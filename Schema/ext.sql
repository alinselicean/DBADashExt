use [DBADashExt];
go

set nocount on;
/*
ext schema will contain all the extensions for alerting
*/
if schema_id('ext') is null exec('create schema [ext] authorization [dbo];');
