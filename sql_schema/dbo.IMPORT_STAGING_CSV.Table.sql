SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_CSV]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IMPORT_STAGING_CSV](
	[Governor ID] [bigint] NULL,
	[Name] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[Power] [bigint] NULL,
	[Alliance] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[T1-Kills] [bigint] NULL,
	[T2-Kills] [bigint] NULL,
	[T3-Kills] [bigint] NULL,
	[T4-Kills] [bigint] NULL,
	[T5-Kills] [bigint] NULL,
	[Total Kill Points] [bigint] NULL,
	[Dead Troops] [bigint] NULL,
	[Healed Troops] [bigint] NULL,
	[Rss Assistance] [bigint] NULL,
	[Alliance Helps] [bigint] NULL,
	[Rss Gathered] [bigint] NULL,
	[City Hall] [int] NULL,
	[Troops Power] [bigint] NULL,
	[Tech Power] [bigint] NULL,
	[Building Power] [bigint] NULL,
	[Commander Power] [bigint] NULL,
	[Civilization] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Autarch Times] [int] NULL,
	[Ranged Points] [bigint] NULL,
	[KvK Played] [int] NULL,
	[Most KvK Kill] [bigint] NULL,
	[Most KvK Dead] [bigint] NULL,
	[Most KvK Heal] [bigint] NULL,
	[Acclaim] [bigint] NULL,
	[Highest Acclaim] [bigint] NULL,
	[AOO Joined] [bigint] NULL,
	[AOO Won] [int] NULL,
	[AOO Avg Kill] [bigint] NULL,
	[AOO Avg Dead] [bigint] NULL,
	[AOO Avg Heal] [bigint] NULL,
	[updated_on] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_CSV]') AND name = N'IX_ImportStagingCsv_Gov')
CREATE NONCLUSTERED INDEX [IX_ImportStagingCsv_Gov] ON [dbo].[IMPORT_STAGING_CSV]
(
	[Governor ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
