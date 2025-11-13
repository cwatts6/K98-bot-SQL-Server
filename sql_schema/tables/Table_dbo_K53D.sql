SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K53D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K53D](
	[GovernorID] [float] NOT NULL,
	[T5_KILLSDelta3Months] [float] NULL
) ON [PRIMARY]
END
