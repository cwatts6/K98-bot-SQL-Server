SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_CSV]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IMPORT_STAGING_CSV](
	[GovernorID] [bigint] NULL,
	[Name] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Power] [bigint] NULL,
	[Alliance] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[T1_Kills] [bigint] NULL,
	[T2_Kills] [bigint] NULL,
	[T3_Kills] [bigint] NULL,
	[T4_Kills] [bigint] NULL,
	[T5_Kills] [bigint] NULL,
	[TotalKillPoints] [bigint] NULL,
	[DeadTroops] [bigint] NULL,
	[RssAssistance] [bigint] NULL,
	[AllianceHelps] [bigint] NULL,
	[RssGathered] [bigint] NULL,
	[CityHall] [int] NULL,
	[TroopsPower] [bigint] NULL,
	[TechPower] [bigint] NULL,
	[BuildingPower] [bigint] NULL,
	[CommanderPower] [bigint] NULL,
	[updated_on] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
END
