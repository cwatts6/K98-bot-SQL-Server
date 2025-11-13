SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K5ALL]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K5ALL](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
) ON [PRIMARY]
END
