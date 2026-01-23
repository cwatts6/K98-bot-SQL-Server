SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KILLPOINTS_D12]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KILLPOINTS_D12](
	[GovernorID] [float] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
) ON [PRIMARY]
END
