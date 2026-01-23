SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTS_ALL]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILLPOINTS_ALL](
	[GovernorID] [float] NOT NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
) ON [PRIMARY]
END
