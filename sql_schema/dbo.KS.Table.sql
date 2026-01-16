SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS](
	[KINGDOM_POWER] [bigint] NULL,
	[Governors] [int] NULL,
	[KP] [float] NULL,
	[KILL] [float] NULL,
	[DEAD] [float] NULL,
	[Last Update] [datetime] NULL,
	[KINGDOM_RANK] [varchar](4) COLLATE Latin1_General_CI_AS NOT NULL,
	[KINGDOM_SEED] [varchar](1) COLLATE Latin1_General_CI_AS NOT NULL,
	[CH25] [int] NULL
) ON [PRIMARY]
END
