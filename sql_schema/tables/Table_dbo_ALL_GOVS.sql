SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ALL_GOVS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ALL_GOVS](
	[GovernorID] [bigint] NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Max Power] [bigint] NULL,
	[Latest Power] [bigint] NULL,
	[KillPoints] [bigint] NULL,
	[T1_Kills] [bigint] NULL,
	[T2_Kills] [bigint] NULL,
	[T3_Kills] [bigint] NULL,
	[T4_Kills] [bigint] NULL,
	[T5_Kills] [bigint] NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[TOTAL_KILLS] [bigint] NULL,
	[Deads] [bigint] NULL,
	[Helps] [bigint] NULL,
	[RSS_Gathered] [bigint] NULL,
	[RSSAssistance] [bigint] NULL,
	[Last Scan] [datetime] NULL,
	[Previous Scan] [datetime] NULL,
	[First Scan] [datetime] NULL
) ON [PRIMARY]
END
