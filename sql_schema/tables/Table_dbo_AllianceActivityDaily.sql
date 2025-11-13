SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDaily]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[AllianceActivityDaily](
	[GovernorID] [int] NOT NULL,
	[AsOfDate] [date] NOT NULL,
	[WeekStartUtc] [datetime2](7) NOT NULL,
	[BuildDonations] [int] NOT NULL,
	[TechDonations] [int] NOT NULL,
	[LastRebuiltFrom] [int] NULL,
 CONSTRAINT [PK_AllianceActivityDaily] PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC,
	[AsOfDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDaily]') AND name = N'IX_AAD_Gov_Date')
CREATE NONCLUSTERED INDEX [IX_AAD_Gov_Date] ON [dbo].[AllianceActivityDaily]
(
	[GovernorID] ASC,
	[AsOfDate] ASC
)
INCLUDE([BuildDonations],[TechDonations]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[AllianceActivityDaily]') AND name = N'IX_AllianceActivityDaily_Week')
CREATE NONCLUSTERED INDEX [IX_AllianceActivityDaily_Week] ON [dbo].[AllianceActivityDaily]
(
	[WeekStartUtc] ASC,
	[AsOfDate] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
