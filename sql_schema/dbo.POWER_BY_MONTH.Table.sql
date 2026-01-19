SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[POWER_BY_MONTH]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[POWER_BY_MONTH](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWER] [float] NULL,
	[KILLPOINTS] [float] NULL,
	[T4&T5KILLS] [float] NULL,
	[DEADS] [float] NULL,
	[MONTH] [date] NULL,
	[HealedTroops] [bigint] NULL,
	[RangedPoints] [bigint] NULL
) ON [PRIMARY]
END
