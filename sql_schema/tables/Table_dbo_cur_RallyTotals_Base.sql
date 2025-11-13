SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[cur_RallyTotals_Base]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[cur_RallyTotals_Base](
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL,
	[TotalRallies] [int] NOT NULL,
	[RalliesLaunched] [int] NOT NULL,
	[RalliesJoined] [int] NOT NULL,
	[SnapshotAt] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__cur_Rally__Snaps__23107701]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[cur_RallyTotals_Base] ADD  DEFAULT (sysutcdatetime()) FOR [SnapshotAt]
END

