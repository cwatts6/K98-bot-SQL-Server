SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[K3]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[K3](
	[GovernorID] [float] NOT NULL,
	[T4&T5_KILLS] [float] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
) ON [PRIMARY]
END
