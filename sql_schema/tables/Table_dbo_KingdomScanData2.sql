SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KingdomScanData2]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KingdomScanData2](
	[PowerRank] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[GovernorID] [float] NOT NULL,
	[GovernorAlliance] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[KillsPoints] [float] NOT NULL,
	[Deads] [float] NOT NULL,
	[T1_Kills] [float] NOT NULL,
	[T2_Kills] [float] NOT NULL,
	[T3_Kills] [float] NOT NULL,
	[T4_Kills] [float] NOT NULL,
	[T5_Kills] [float] NOT NULL,
	[RSSAssistance] [float] NOT NULL,
	[Helps] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[SCANORDER] [float] NOT NULL,
	[SCAN_UNO] [int] IDENTITY(1,1) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[SCAN_UNO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
