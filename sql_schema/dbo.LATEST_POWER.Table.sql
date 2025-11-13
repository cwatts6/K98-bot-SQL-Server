SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LATEST_POWER]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LATEST_POWER](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[PowerRank] [float] NOT NULL,
	[POWER] [float] NOT NULL
) ON [PRIMARY]
END
