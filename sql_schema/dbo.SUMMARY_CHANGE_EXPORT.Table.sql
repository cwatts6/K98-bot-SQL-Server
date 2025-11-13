SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SUMMARY_CHANGE_EXPORT]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SUMMARY_CHANGE_EXPORT](
	[GOVERNORID] [float] NOT NULL,
	[GOVERNORNAME] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4&T5_KILLS] [float] NULL,
	[StartingT4&T5_KILLS] [float] NULL,
	[OverallT4&T5_KILLSDelta] [float] NULL,
	[T4&T5_KILLSDelta12Months] [float] NOT NULL,
	[T4&T5_KILLSDelta6Months] [float] NOT NULL,
	[T4&T5_KILLSDelta3Months] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[StartingT4_KILLS] [float] NULL,
	[OverallT4_KILLSDelta] [float] NULL,
	[T4_KILLSDelta12Months] [float] NOT NULL,
	[T4_KILLSDelta6Months] [float] NOT NULL,
	[T4_KILLSDelta3Months] [float] NOT NULL,
	[T5_Kills] [float] NOT NULL,
	[StartingT5_Kills] [float] NULL,
	[OverallT5_KillsDelta] [float] NULL,
	[T5_KillsDelta12Months] [float] NOT NULL,
	[T5_KillsDelta6Months] [float] NOT NULL,
	[T5_KillsDelta3Months] [float] NOT NULL,
	[POWER] [float] NOT NULL,
	[StartingPower] [float] NULL,
	[OverallPowerDelta] [float] NULL,
	[PowerDelta12Months] [float] NULL,
	[PowerDelta6Months] [float] NULL,
	[PowerDelta3Months] [float] NULL,
	[DEADS] [float] NOT NULL,
	[StartingDEADS] [float] NULL,
	[OverallDEADSDelta] [float] NULL,
	[DEADSDelta12Months] [float] NULL,
	[DEADSDelta6Months] [float] NULL,
	[DEADSDelta3Months] [float] NULL
) ON [PRIMARY]
END
