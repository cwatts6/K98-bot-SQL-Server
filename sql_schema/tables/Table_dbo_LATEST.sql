SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LATEST]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LATEST](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[PowerRank] [float] NOT NULL,
	[DEADS] [float] NOT NULL
) ON [PRIMARY]
END
