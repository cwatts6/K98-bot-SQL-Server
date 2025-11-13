SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K46]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K46](
	[GovernorID] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
) ON [PRIMARY]
END
