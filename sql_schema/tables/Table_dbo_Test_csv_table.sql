SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Test_csv_table]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Test_csv_table](
	[FileName] [varchar](max) COLLATE Latin1_General_CI_AS NULL,
	[PowerSum] [float] NULL,
	[Date_Scanned] [date] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
