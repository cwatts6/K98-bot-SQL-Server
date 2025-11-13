SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RALLY_JOINERS]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RALLY_JOINERS](
	[ID] [bigint] NULL,
	[Col1] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col2] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col3] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col4] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col5] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col6] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col7] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col8] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col9] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col10] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col11] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col12] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col13] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col14] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col15] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Col16] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
