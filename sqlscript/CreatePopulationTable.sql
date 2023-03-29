IF NOT EXISTS (SELECT * FROM sys.objects O JOIN sys.schemas S ON O.schema_id = S.schema_id WHERE O.NAME = 'Population' AND O.TYPE = 'U' AND S.NAME = 'dbo')

CREATE TABLE dbo.Population
(
	[ID] bigint,
	[ZipCode] bigint,
	[Population] bigint
)
WITH
(
	DISTRIBUTION = ROUND_ROBIN,
	CLUSTERED COLUMNSTORE INDEX
)
GO

COPY INTO dbo.Population
	([ID] 1, [ZipCode] 2, [Population] 3)
FROM 'https://datalakexxxxxxx.dfs.core.windows.net/files/data/raw/population.csv'
WITH
(
	FILE_TYPE = 'CSV',
	FIRSTROW = 2
)
GO