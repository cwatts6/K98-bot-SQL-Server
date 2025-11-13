SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcConfig_Staging]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ProcConfig_Staging](
	[KVK_NO] [int] NULL,
	[LASTKVKEND] [int] NULL,
	[MATCHMAKING_SCAN] [int] NULL,
	[PRE_PASS_4_SCAN] [int] NULL,
	[PASS4END] [int] NULL,
	[PASS6END] [int] NULL,
	[PASS7END] [int] NULL,
	[KVK_END_SCAN] [int] NULL,
	[CURRENTKVK3] [int] NULL,
	[DRAFTSCAN] [int] NULL
) ON [PRIMARY]
END
