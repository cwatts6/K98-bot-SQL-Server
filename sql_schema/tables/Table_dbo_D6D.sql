SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[D6D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[D6D](
	[GovernorID] [float] NOT NULL,
	[DEADSDelta6Months] [float] NULL
) ON [PRIMARY]
END
