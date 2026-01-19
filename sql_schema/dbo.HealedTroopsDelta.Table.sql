SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HealedTroopsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[HealedTroopsDelta](
	[GovernorID] [bigint] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[HealedTroopsDelta] [bigint] NULL
) ON [PRIMARY]
END
