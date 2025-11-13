SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILL5SUMMARY]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILL5SUMMARY](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWERRank] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[StartingT5_KILLS] [float] NULL,
	[OverallT5_KILLSDelta] [float] NULL,
	[T5_KILLSDelta12Months] [float] NOT NULL,
	[T5_KILLSDelta6Months] [float] NOT NULL,
	[T5_KILLSDelta3Months] [float] NOT NULL
) ON [PRIMARY]
END
