SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RANGED_D12D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RANGED_D12D](
	[GovernorID] [bigint] NOT NULL,
	[RangedPointsDelta12Months] [bigint] NULL
) ON [PRIMARY]
END
