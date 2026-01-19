SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HEALED_D12D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[HEALED_D12D](
	[GovernorID] [bigint] NOT NULL,
	[HealedTroopsDelta12Months] [bigint] NULL
) ON [PRIMARY]
END
