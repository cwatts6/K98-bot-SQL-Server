SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RANGED_D6D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RANGED_D6D](
	[GovernorID] [bigint] NOT NULL,
	[RangedPointsDelta6Months] [bigint] NULL
) ON [PRIMARY]
END
