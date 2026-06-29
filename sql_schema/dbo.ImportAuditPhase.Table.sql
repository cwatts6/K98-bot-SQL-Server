SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ImportAuditPhase](
	[ImportAuditPhaseId] [bigint] IDENTITY(1,1) NOT NULL,
	[ImportAuditBatchId] [bigint] NOT NULL,
	[PhaseName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[PhaseStatus] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[StartedAtUtc] [datetime2](3) NOT NULL,
	[CompletedAtUtc] [datetime2](3) NULL,
	[RowsIn] [int] NULL,
	[RowsOut] [int] NULL,
	[DurationMs] [int] NULL,
	[ErrorType] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[ErrorText] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ImportAuditPhase] PRIMARY KEY CLUSTERED 
(
	[ImportAuditPhaseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]') AND name = N'IX_ImportAuditPhase_BatchPhase')
CREATE NONCLUSTERED INDEX [IX_ImportAuditPhase_BatchPhase] ON [dbo].[ImportAuditPhase]
(
	[ImportAuditBatchId] ASC,
	[StartedAtUtc] ASC,
	[ImportAuditPhaseId] ASC
)
INCLUDE([PhaseName],[PhaseStatus],[RowsIn],[RowsOut],[DurationMs]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditPhase_StartedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditPhase] ADD  CONSTRAINT [DF_ImportAuditPhase_StartedAtUtc]  DEFAULT (sysutcdatetime()) FOR [StartedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditPhase_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditPhase] ADD  CONSTRAINT [DF_ImportAuditPhase_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ImportAuditPhase_Batch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] WITH CHECK ADD CONSTRAINT [FK_ImportAuditPhase_Batch] FOREIGN KEY([ImportAuditBatchId])
REFERENCES [dbo].[ImportAuditBatch] ([ImportAuditBatchId])
IF EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ImportAuditPhase_Batch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] CHECK CONSTRAINT [FK_ImportAuditPhase_Batch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditPhase_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] WITH CHECK ADD CONSTRAINT [CK_ImportAuditPhase_Status] CHECK (([PhaseStatus]=N'rolled_back' OR [PhaseStatus]=N'cancelled' OR [PhaseStatus]=N'duplicate' OR [PhaseStatus]=N'skipped' OR [PhaseStatus]=N'failed' OR [PhaseStatus]=N'completed' OR [PhaseStatus]=N'started'))
IF EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditPhase_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] CHECK CONSTRAINT [CK_ImportAuditPhase_Status]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditPhase_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] WITH CHECK ADD CONSTRAINT [CK_ImportAuditPhase_DetailsJson] CHECK (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditPhase_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditPhase]'))
ALTER TABLE [dbo].[ImportAuditPhase] CHECK CONSTRAINT [CK_ImportAuditPhase_DetailsJson]
