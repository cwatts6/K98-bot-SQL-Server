SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[D3D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[D3D](
	[GovernorID] [float] NOT NULL,
	[DEADSDelta3Months] [float] NULL
) ON [PRIMARY]
END
