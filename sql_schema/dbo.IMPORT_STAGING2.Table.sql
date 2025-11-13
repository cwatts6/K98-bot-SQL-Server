SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING2]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IMPORT_STAGING2](
	[Governor Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Governor ID] [float] NOT NULL,
	[Alliance] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NOT NULL,
	[Kill Points] [float] NOT NULL,
	[Deaths] [float] NOT NULL,
	[T1] [float] NOT NULL,
	[T2] [float] NOT NULL,
	[T3] [float] NOT NULL,
	[T4] [float] NOT NULL,
	[T5] [float] NOT NULL,
	[Kills (T4+)] [float] NULL,
	[KILLS] [float] NULL,
	[RSS Gathered] [float] NULL,
	[RSS Assistance] [float] NOT NULL,
	[Helps] [float] NOT NULL,
	[ScanDate] [datetime] NULL,
	[SCANORDER] [float] NULL
) ON [PRIMARY]
END
