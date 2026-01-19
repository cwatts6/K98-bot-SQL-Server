SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RangedPointsDelta]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RangedPointsDelta](
	[GovernorID] [bigint] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[RangedPointsDelta] [bigint] NULL
) ON [PRIMARY]
END
