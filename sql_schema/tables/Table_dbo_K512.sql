SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K512]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K512](
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
) ON [PRIMARY]
END
