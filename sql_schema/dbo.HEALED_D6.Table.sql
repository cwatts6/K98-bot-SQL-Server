SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HEALED_D6]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[HEALED_D6](
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
) ON [PRIMARY]
END
