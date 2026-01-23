SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTS_D6]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILLPOINTS_D6](
	[GovernorID] [float] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
) ON [PRIMARY]
END
