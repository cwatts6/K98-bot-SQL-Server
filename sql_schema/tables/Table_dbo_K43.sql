SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K43]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K43](
	[GovernorID] [float] NOT NULL,
	[T4_KILLS] [float] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
) ON [PRIMARY]
END
