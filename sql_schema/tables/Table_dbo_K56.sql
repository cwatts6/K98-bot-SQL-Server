SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K56]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K56](
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
) ON [PRIMARY]
END
