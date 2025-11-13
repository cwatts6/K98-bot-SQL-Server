SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TT]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TT](
	[Governor ID] [float] NOT NULL,
	[Governor Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Kill Points] [float] NOT NULL,
	[KillPoints] [float] NULL
) ON [PRIMARY]
END
