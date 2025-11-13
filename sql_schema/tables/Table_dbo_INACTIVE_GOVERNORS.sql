SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[INACTIVE_GOVERNORS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[INACTIVE_GOVERNORS](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[Inactive_Date] [datetime] NOT NULL,
	[Status] [varchar](19) COLLATE Latin1_General_CI_AS NOT NULL
) ON [PRIMARY]
END
