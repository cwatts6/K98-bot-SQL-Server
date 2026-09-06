SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_CSV_RAW]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IMPORT_STAGING_CSV_RAW](
	[Governor ID] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Name] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Alliance] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[T1-Kills] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[T2-Kills] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[T3-Kills] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[T4-Kills] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[T5-Kills] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Total Kill Points] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Dead Troops] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Healed Troops] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Rss Assistance] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Alliance Helps] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Rss Gathered] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[City Hall] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Troops Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Tech Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Building Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Commander Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Civilization] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[Autarch Times] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Ranged Points] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[KvK Played] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Most KvK Kill] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Most KvK Dead] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Most KvK Heal] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Acclaim] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Highest Acclaim] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[AOO Joined] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[AOO Won] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[AOO Avg Kill] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[AOO Avg Dead] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[AOO Avg Heal] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Credit] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[updated_on] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
END
