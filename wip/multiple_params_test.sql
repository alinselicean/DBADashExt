DECLARE @tags NVARCHAR(MAX);
DECLARE @thrs NVARCHAR(MAX);

SET @tags = N'[{ "tags": {"name": "Role", "values": ["SQL", "C#", "Azure"]} }]';

SELECT --id, 
	tag,  tagvalue
FROM OPENJSON(@tags)  
  WITH (
    --id INT 'strict $.id',
    tag NVARCHAR(50) 'strict $.tags.name',
    tagvalues NVARCHAR(MAX) '$.tags.values' AS JSON
  )
OUTER APPLY OPENJSON(tagvalues)
  WITH (tagvalue NVARCHAR(128) '$');


set @thrs = N'
[{ "thresholds": {"name": "MinBlockedSessions", "value": "10"}}, 
 { "thresholds": {"name": "MinBlockedWaitTimeMs", "value": "10000"}}
]';
SELECT *
FROM OPENJSON(@thrs)
  WITH (
    threshold NVARCHAR(50) 'strict $.thresholds.name',
    limit NVARCHAR(50) '$.thresholds.value'
  );
