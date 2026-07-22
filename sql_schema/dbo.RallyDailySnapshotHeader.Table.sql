SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RallyDailySnapshotHeader](
	[AsOfDate] [date] NOT NULL,
	[CompletedAtUtc] [datetime2](0) NOT NULL,
	[SourceRowCount] [int] NOT NULL,
	[DistinctGovernorCount] [int] NOT NULL,
	[Revision] [int] NOT NULL,
	[CompletionBasis] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[ImportBatchID] [bigint] NULL,
 CONSTRAINT [PK_RallyDailySnapshotHeader] PRIMARY KEY CLUSTERED 
(
	[AsOfDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader]  WITH CHECK ADD  CONSTRAINT [CK_RallyDailySnapshotHeader_Basis] CHECK  (([CompletionBasis]=N'INFERRED_DATE' OR [CompletionBasis]=N'OTHER_AUTHORITY' OR [CompletionBasis]=N'AUDIT_BACKFILL' OR [CompletionBasis]=N'LIVE_IMPORT'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader] CHECK CONSTRAINT [CK_RallyDailySnapshotHeader_Basis]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Counts]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader]  WITH CHECK ADD  CONSTRAINT [CK_RallyDailySnapshotHeader_Counts] CHECK  (([SourceRowCount]>=(0) AND [DistinctGovernorCount]>=(0) AND [DistinctGovernorCount]<=[SourceRowCount]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Counts]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader] CHECK CONSTRAINT [CK_RallyDailySnapshotHeader_Counts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Revision]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader]  WITH CHECK ADD  CONSTRAINT [CK_RallyDailySnapshotHeader_Revision] CHECK  (([Revision]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_RallyDailySnapshotHeader_Revision]') AND parent_object_id = OBJECT_ID(N'[dbo].[RallyDailySnapshotHeader]'))
ALTER TABLE [dbo].[RallyDailySnapshotHeader] CHECK CONSTRAINT [CK_RallyDailySnapshotHeader_Revision]
