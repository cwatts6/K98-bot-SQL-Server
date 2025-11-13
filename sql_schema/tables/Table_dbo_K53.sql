SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K53]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K53](
	[GovernorID] [float] NOT NULL,
	[T5_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
) ON [PRIMARY]
END
