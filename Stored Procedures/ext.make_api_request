use [DBADashExt];
go

set ansi_nulls, quoted_identifier on
go

if object_id('[ext].[make_api_request]') is null exec('create PROCEDURE [ext].[make_api_request] as begin select 1 end;');
go

/*
Requires 'Ole Automation Procedures' advanced configuration enabled

sp_configure 'show advanced options', 1 
reconfigure with override; 

sp_configure 'Ole Automation Procedures', 1 
reconfigure with override; 

-- Need HTTPS in the outbound rules
-- open for hooks.slack.com (3.123.248.34)
*/
alter procedure [ext].[make_api_request]
(
	@RTYPE VARCHAR(MAX),
	@authHeader VARCHAR(MAX), 
	@RPAYLOAD VARCHAR(MAX), 
	@URL VARCHAR(MAX),
	@OUTSTATUS VARCHAR(MAX) OUTPUT,
	@OUTRESPONSE VARCHAR(MAX) OUTPUT
)
AS
BEGIN 
	DECLARE @contentType NVARCHAR(64);
	DECLARE @postData NVARCHAR(2000);
	DECLARE @responseText NVARCHAR(2000);
	DECLARE @responseXML NVARCHAR(2000);
	DECLARE @ret INT;
	DECLARE @status NVARCHAR(32);
	DECLARE @statusText NVARCHAR(32);
	DECLARE @token INT;

	SET @contentType = 'application/json';

	-- Open the connection.
	EXEC @ret = sp_OACreate 'MSXML2.ServerXMLHTTP', @token OUT;
	IF @ret <> 0 RAISERROR('Unable to open HTTP connection.', 10, 1);

	-- Send the request.
	EXEC @ret = sp_OAMethod @token, 'open', NULL, @RTYPE, @url, 'false';
	EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Authentication', @authHeader;
	EXEC @ret = sp_OAMethod @token, 'setRequestHeader', NULL, 'Content-type', 'application/json';
	SET @RPAYLOAD = (SELECT CASE WHEN @RTYPE = 'Get' THEN NULL ELSE @RPAYLOAD END )
	EXEC @ret = sp_OAMethod @token, 'send', NULL, @RPAYLOAD; -- IF YOUR POSTING, CHANGE THE LAST NULL TO @postData

	-- Handle the response.
	EXEC @ret = sp_OAGetProperty @token, 'status', @status OUT;
	EXEC @ret = sp_OAGetProperty @token, 'statusText', @statusText OUT;
	EXEC @ret = sp_OAGetProperty @token, 'responseText', @responseText OUT;

	-- Show the response.
	PRINT 'Status: ' + @status + ' (' + @statusText + ')';
	PRINT 'Response text: ' + @responseText;
	SET @OUTSTATUS = 'Status: ' + @status + ' (' + @statusText + ')'
	SET @OUTRESPONSE = 'Response text: ' + @responseText;

	-- Close the connection.
	EXEC @ret = sp_OADestroy @token;
	IF @ret <> 0 RAISERROR('Unable to close HTTP connection.', 10, 1);
END
go
