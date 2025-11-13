SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K6]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K6](
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
) ON [PRIMARY]
END
