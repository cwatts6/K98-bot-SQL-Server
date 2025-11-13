SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TARGETS_4]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TARGETS_4](
	[GovernorID] [float] NOT NULL,
	[Kill_Target] [int] NULL,
	[Minimum_Kill_Target] [int] NULL,
	[Dead_Target] [int] NULL
) ON [PRIMARY]
END
