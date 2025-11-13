SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXEMPT_FROM_STATS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXEMPT_FROM_STATS](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Exempt] [bit] NULL,
	[KVK_NO] [float] NULL
) ON [PRIMARY]
END
