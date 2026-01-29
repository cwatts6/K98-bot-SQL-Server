SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeadsDelta_BACKUP]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DeadsDelta_BACKUP](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[DeadsDelta] [float] NULL
) ON [PRIMARY]
END
