SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILL4SUMMARY]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILL4SUMMARY](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWERRank] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[StartingT4_KILLS] [float] NULL,
	[OverallT4_KILLSDelta] [float] NULL,
	[T4_KILLSDelta12Months] [float] NOT NULL,
	[T4_KILLSDelta6Months] [float] NOT NULL,
	[T4_KILLSDelta3Months] [float] NOT NULL
) ON [PRIMARY]
END
