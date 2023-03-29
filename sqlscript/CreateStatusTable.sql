IF NOT EXISTS (SELECT * FROM sys.objects O JOIN sys.schemas S ON O.schema_id = S.schema_id WHERE O.NAME = 'Status' AND O.TYPE = 'U' AND S.NAME = 'dbo')

CREATE TABLE dbo.Status
(
	[CustomerID] nvarchar(4000),
	[SatisfactionScore] bigint,
	[CLTV] bigint
)
WITH
(
	DISTRIBUTION = ROUND_ROBIN,
	CLUSTERED COLUMNSTORE INDEX
)
GO

COPY INTO dbo.Status
	([CustomerID] 1, [SatisfactionScore] 2, [CLTV] 3)
FROM 'https://datalakexxxxxxx.dfs.core.windows.net/files/data/raw/status.csv'
WITH
(
	FILE_TYPE = 'CSV',
	FIRSTROW = 2
)
GO