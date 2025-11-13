SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PowerSplit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PowerSplit](
	[Governor ID] [float] NULL,
	[Governor Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [float] NULL,
	[Troops Power] [float] NULL,
	[Alliance] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T1-Kills] [float] NULL,
	[T2-Kills] [float] NULL,
	[T3-Kills] [float] NULL,
	[T4-Kills] [float] NULL,
	[T5-Kills] [float] NULL,
	[Total Kill Points] [float] NULL,
	[Dead Troops] [float] NULL,
	[Rss Assistance] [float] NULL,
	[Alliance Helps] [float] NULL,
	[Rss Gathered] [float] NULL,
	[City Hall] [float] NULL,
	[Tech Power] [float] NULL,
	[Building Power] [float] NULL,
	[Commander Power] [float] NULL,
	[updated_on] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
END
