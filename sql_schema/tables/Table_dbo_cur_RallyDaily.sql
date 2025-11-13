SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cur_RallyDaily]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[cur_RallyDaily](
	[AsOfDate] [date] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL,
	[TotalRallies] [int] NOT NULL,
	[RalliesLaunched] [int] NOT NULL,
	[RalliesJoined] [int] NOT NULL,
	[InsertedAt] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_cur_RallyDaily] PRIMARY KEY CLUSTERED 
(
	[AsOfDate] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[cur_RallyDaily]') AND name = N'IX_cur_RallyDaily_AsOf_Gov')
CREATE NONCLUSTERED INDEX [IX_cur_RallyDaily_AsOf_Gov] ON [dbo].[cur_RallyDaily]
(
	[AsOfDate] ASC,
	[GovernorID] ASC
)
INCLUDE([GovernorName],[TotalRallies],[RalliesLaunched],[RalliesJoined]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[cur_RallyDaily]') AND name = N'IX_RallyDaily_Gov_Date')
CREATE NONCLUSTERED INDEX [IX_RallyDaily_Gov_Date] ON [dbo].[cur_RallyDaily]
(
	[GovernorID] ASC,
	[AsOfDate] ASC
)
INCLUDE([TotalRallies],[RalliesLaunched],[RalliesJoined]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__cur_Rally__Inser__20340A56]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[cur_RallyDaily] ADD  DEFAULT (sysutcdatetime()) FOR [InsertedAt]
END

