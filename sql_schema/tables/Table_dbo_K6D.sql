SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K6D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K6D](
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLSDelta6Months] [float] NULL
) ON [PRIMARY]
END
