SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[STATS_FOR_UPLOAD]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[STATS_FOR_UPLOAD](
	[Rank] [float] NOT NULL,
	[KVK_RANK] [bigint] NULL,
	[Governor ID] [float] NOT NULL,
	[Governor_Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[Power Delta] [float] NOT NULL,
	[T4_Kills] [float] NOT NULL,
	[T5_Kills] [float] NOT NULL,
	[T4&T5_Kills] [float] NOT NULL,
	[OFF_SEASON_KILLS] [float] NULL,
	[Kill Target] [int] NULL,
	[% of Kill target] [float] NOT NULL,
	[Deads] [float] NOT NULL,
	[OFF_SEASON_DEADS] [float] NULL,
	[T4_Deads] [float] NULL,
	[T5_Deads] [float] NULL,
	[Dead Target] [int] NULL,
	[% of Dead Target] [float] NOT NULL,
	[Zeroed] [int] NULL,
	[DKP_SCORE] [float] NOT NULL,
	[DKP Target] [int] NULL,
	[% of DKP Target] [float] NOT NULL,
	[Helps] [float] NOT NULL,
	[RSS_Assist] [float] NOT NULL,
	[RSS_Gathered] [float] NOT NULL,
	[Pass 4 Kills] [float] NOT NULL,
	[Pass 6 Kills] [float] NOT NULL,
	[Pass7 Kills] [float] NOT NULL,
	[Pass 8 Kills] [float] NOT NULL,
	[Pass 4 Deads] [float] NOT NULL,
	[Pass 6 Deads] [float] NOT NULL,
	[Pass 7 Deads] [float] NOT NULL,
	[Pass 8 Deads] [float] NOT NULL,
	[KVK_NO] [float] NULL,
	[LAST_REFRESH] [date] NULL,
	[STATUS] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__STATS_FOR__STATU__2F1FB17D]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[STATS_FOR_UPLOAD] ADD  DEFAULT ('INCLUDED') FOR [STATUS]
END

