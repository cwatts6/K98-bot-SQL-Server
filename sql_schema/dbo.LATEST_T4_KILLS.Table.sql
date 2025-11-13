SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LATEST_T4_KILLS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LATEST_T4_KILLS](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWERRank] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL
) ON [PRIMARY]
END
