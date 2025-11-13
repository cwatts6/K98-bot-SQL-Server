SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[P12D]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[P12D](
	[GovernorID] [float] NOT NULL,
	[POWERDelta12Months] [float] NULL
) ON [PRIMARY]
END
