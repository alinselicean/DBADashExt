/*
InstanceDisplayName	DB					File				SizeMB			TotalGrowthMB	is_percent_growth	AutoGrowthPct	AutoGrowthMB	AutoGrowCount
ERP-011				tempdb				tempdev				142792.000000	109760.000000	0					NULL			64.000000		1715
ERP-006				ERP_NO_REAL_0009	ERP_NO_REAL_0009	215877.000000	501.000000		0					NULL			1.000000		501
ERP-020				tempdb				tempdev				18888.000000	18880.000000	0					NULL			64.000000		295
*/

SELECT I.[InstanceDisplayName],
		D.[name] AS [DB], 
		F.[name] AS [File],
		F.[size]/128.0 AS [SizeMB],
		(F.[size] - SS.[Size])/128.0 AS [TotalGrowthMB], /* Diff between file size now and 2 days ago */
		F.[is_percent_growth],
		CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] ELSE NULL END AS AutoGrowthPct,
		CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] * 0.01 * SS.[Size] ELSE F.[growth] END / 128.0 AS [AutoGrowthMB], /* Growth in MB  - converting % growth into MB */
		CAST((F.[size]-SS.[Size]) / NULLIF(CASE WHEN F.[is_percent_growth] = 1 THEN F.[growth] * 0.01 * SS.[Size] ELSE F.[growth] END,0) AS INT) AS AutoGrowCount 
		/* Calculate autogrowth count based on change in size and autogrpowth increment.  Note: Files could have been grown manually */
FROM dbo.[Instances] I 
JOIN dbo.[Databases] D ON D.[InstanceID] = I.[InstanceID]
JOIN dbo.[DBFiles] F ON F.[DatabaseID] = D.[DatabaseID]
OUTER APPLY (SELECT TOP(1) FSS.[Size]
			FROM dbo.[DBFileSnapshot] FSS 
			WHERE FSS.[FileID] = F.[FileID]
			AND FSS.[SnapshotDate] >= CAST(DATEADD(d,-120,GETUTCDATE()) AS DATETIME2(2))
			ORDER BY FSS.[SnapshotDate]
			) SS /* Get the file size from 2 days ago */
WHERE I.[IsActive] = 1
AND F.[IsActive] = 1
AND D.[IsActive] = 1
AND F.[size] - SS.[Size] > 0
ORDER BY [AutoGrowCount] DESC
