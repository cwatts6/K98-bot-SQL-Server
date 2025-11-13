SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TEMPSUM]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TEMPSUM](
	[GovernorID] [float] NULL,
	[KP] [float] NULL,
	[ScanDate] [datetime] NULL
) ON [PRIMARY]
END
