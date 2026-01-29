SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RSSGatheredDelta_BACKUP]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RSSGatheredDelta_BACKUP](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[RSSGatheredDelta] [float] NULL
) ON [PRIMARY]
END
