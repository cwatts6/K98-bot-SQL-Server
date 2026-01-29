SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[POWERDelta_BACKUP]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[POWERDelta_BACKUP](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[Power_Delta] [float] NULL
) ON [PRIMARY]
END
