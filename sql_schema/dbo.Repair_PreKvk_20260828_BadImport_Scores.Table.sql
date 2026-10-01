SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repair_PreKvk_20260828_BadImport_Scores]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Repair_PreKvk_20260828_BadImport_Scores](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Points] [int] NOT NULL,
	[KingdomID] [int] NULL,
	[SourceRank] [int] NULL,
	[Stage1Points] [int] NULL,
	[Stage2Points] [int] NULL,
	[Stage3Points] [int] NULL,
	[TotalPoints] [int] NULL
) ON [PRIMARY]
END
