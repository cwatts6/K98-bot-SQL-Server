SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_FOR_JUL23_KVK]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_FOR_JUL23_KVK](
	[Rank] [float] NOT NULL,
	[KVK_RANK] [bigint] NULL,
	[Gov_ID] [float] NULL,
	[Governor_Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[POWER_DELTA] [float] NULL,
	[T4_KILLS] [float] NULL,
	[T5_KILLS] [float] NULL,
	[T4&T5_Kills] [float] NULL,
	[KILLS_OUTSIDE_KVK] [float] NULL,
	[Kill Target] [float] NULL,
	[% of Kill target] [float] NULL,
	[Deads] [float] NULL,
	[DEADS_OUTSIDE_KVK] [float] NULL,
	[T4_Deads] [float] NULL,
	[T5_Deads] [float] NULL,
	[Dead Target] [float] NULL,
	[% of Dead Target] [float] NULL,
	[Zeroed] [bit] NULL,
	[DKP_Score] [float] NULL,
	[DKP Target] [float] NULL,
	[% of DKP Target] [float] NULL,
	[Helps] [float] NULL,
	[RSS_Assist] [float] NULL,
	[RSS_Gathered] [float] NULL,
	[Pass 4 Kills] [float] NULL,
	[Pass 6 Kills] [float] NULL,
	[Pass7 Kills] [float] NULL,
	[Pass 8 Kills] [float] NULL,
	[Pass 4 Deads] [float] NULL,
	[Pass 6 Deads] [float] NULL,
	[Pass 7 Deads] [float] NULL,
	[Pass 8 Deads] [float] NULL,
	[KVK_NO] [varchar](1) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
END
