IF NOT EXISTS (SELECT * FROM sys.objects O JOIN sys.schemas S ON O.schema_id = S.schema_id WHERE O.NAME = 'Customer' AND O.TYPE = 'U' AND S.NAME = 'dbo')

CREATE TABLE dbo.Customer
(
	[CustomerID] nvarchar(4000),
	[Gender] nvarchar(4000),
	[Age] bigint,
	[Under30] nvarchar(4000),
	[SeniorCitizen] nvarchar(4000),
	[Married] nvarchar(4000),
	[Dependents] nvarchar(4000),
	[NumberDependents] bigint,
	[Country] nvarchar(4000),
	[State] nvarchar(4000),
	[City] nvarchar(4000),
	[ZipCode] bigint,
	[Latitude] float,
	[Longitude] float,
	[ReferredFriend] nvarchar(4000),
	[NumberReferrals] bigint,
	[TenureMonths] bigint,
	[Offer] nvarchar(4000),
	[PhoneService] nvarchar(4000),
	[AvgMonthlyLongDistanceCharges] float,
	[MultipleLines] nvarchar(4000),
	[InternetService] nvarchar(4000),
	[InternetType] nvarchar(4000),
	[AvgMonthlyGBDownload] bigint,
	[OnlineSecurity] nvarchar(4000),
	[OnlineBackup] nvarchar(4000),
	[DeviceProtectionPlan] nvarchar(4000),
	[PremiumTechSupport] nvarchar(4000),
	[StreamingTV] nvarchar(4000),
	[StreamingMovies] nvarchar(4000),
	[StreamingMusic] nvarchar(4000),
	[UnlimitedData] nvarchar(4000),
	[Contract] nvarchar(4000),
	[PaperlessBilling] nvarchar(4000),
	[PaymentMethod] nvarchar(4000),
	[MonthlyCharge] float,
	[TotalCharges] float,
	[TotalRefunds] float,
	[TotalExtraDataCharges] bigint,
	[TotalLongDistanceCharges] float,
	[TotalRevenue] float
)
WITH
(
	DISTRIBUTION = ROUND_ROBIN,
	CLUSTERED COLUMNSTORE INDEX
)
GO

COPY INTO dbo.Customer
	([CustomerID] 1, [Gender] 2, [Age] 3, [Under30] 4, [SeniorCitizen] 5, [Married] 6, [Dependents] 7, [NumberDependents] 8, [Country] 9, [State] 10, [City] 11, [ZipCode] 12, [Latitude] 13, [Longitude] 14, [ReferredFriend] 15, [NumberReferrals] 16, [TenureMonths] 17, [Offer] 18, [PhoneService] 19, [AvgMonthlyLongDistanceCharges] 20, [MultipleLines] 21, [InternetService] 22, [InternetType] 23, [AvgMonthlyGBDownload] 24, [OnlineSecurity] 25, [OnlineBackup] 26, [DeviceProtectionPlan] 27, [PremiumTechSupport] 28, [StreamingTV] 29, [StreamingMovies] 30, [StreamingMusic] 31, [UnlimitedData] 32, [Contract] 33, [PaperlessBilling] 34, [PaymentMethod] 35, [MonthlyCharge] 36, [TotalCharges] 37, [TotalRefunds] 38, [TotalExtraDataCharges] 39, [TotalLongDistanceCharges] 40, [TotalRevenue] 41)
FROM 'https://datalakexxxxxxx.dfs.core.windows.net/files/data/transformed/customer.csv'
WITH
(
	FILE_TYPE = 'CSV',
	FIRSTROW = 2
)
GO