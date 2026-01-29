SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[T4KillDelta_BACKUP]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[T4KillDelta_BACKUP](
	[GovernorID] [float] NOT NULL,
	[DeltaOrder] [float] NOT NULL,
	[T4KILLSDelta] [float] NULL
) ON [PRIMARY]
END
