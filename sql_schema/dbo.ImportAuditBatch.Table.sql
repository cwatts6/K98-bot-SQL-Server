SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ImportAuditBatch](
	[ImportAuditBatchId] [bigint] IDENTITY(1,1) NOT NULL,
	[CorrelationId] [uniqueidentifier] NOT NULL,
	[ImportKind] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceType] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[SourceFilename] [nvarchar](260) COLLATE Latin1_General_CI_AS NULL,
	[SourceFileHashSha256] [char](64) COLLATE Latin1_General_CI_AS NULL,
	[SourceMessageId] [bigint] NULL,
	[SourceChannelId] [bigint] NULL,
	[ActorDiscordId] [bigint] NULL,
	[QueueName] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[QueueChannelId] [bigint] NULL,
	[ExternalBatchTable] [nvarchar](256) COLLATE Latin1_General_CI_AS NULL,
	[ExternalBatchId] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[Status] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[StartedAtUtc] [datetime2](3) NOT NULL,
	[CompletedAtUtc] [datetime2](3) NULL,
	[RowsInSource] [int] NULL,
	[RowsStaged] [int] NULL,
	[RowsWritten] [int] NULL,
	[RowsSkipped] [int] NULL,
	[ErrorType] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[ErrorText] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ImportAuditBatch] PRIMARY KEY CLUSTERED 
(
	[ImportAuditBatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ImportAuditBatch_CorrelationId] UNIQUE NONCLUSTERED 
(
	[CorrelationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]') AND name = N'IX_ImportAuditBatch_KindStatusStarted')
CREATE NONCLUSTERED INDEX [IX_ImportAuditBatch_KindStatusStarted] ON [dbo].[ImportAuditBatch]
(
	[ImportKind] ASC,
	[Status] ASC,
	[StartedAtUtc] DESC
)
INCLUDE([SourceFilename],[ExternalBatchTable],[ExternalBatchId],[RowsWritten]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]') AND name = N'IX_ImportAuditBatch_ExternalBatch')
CREATE NONCLUSTERED INDEX [IX_ImportAuditBatch_ExternalBatch] ON [dbo].[ImportAuditBatch]
(
	[ExternalBatchTable] ASC,
	[ExternalBatchId] ASC,
	[StartedAtUtc] DESC
)
WHERE ([ExternalBatchTable] IS NOT NULL AND [ExternalBatchId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditBatch_CorrelationId]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditBatch] ADD  CONSTRAINT [DF_ImportAuditBatch_CorrelationId]  DEFAULT (newid()) FOR [CorrelationId]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditBatch_StartedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditBatch] ADD  CONSTRAINT [DF_ImportAuditBatch_StartedAtUtc]  DEFAULT (sysutcdatetime()) FOR [StartedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditBatch_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditBatch] ADD  CONSTRAINT [DF_ImportAuditBatch_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ImportAuditBatch_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ImportAuditBatch] ADD  CONSTRAINT [DF_ImportAuditBatch_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditBatch_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]'))
ALTER TABLE [dbo].[ImportAuditBatch] WITH CHECK ADD CONSTRAINT [CK_ImportAuditBatch_Status] CHECK (([Status]=N'rolled_back' OR [Status]=N'cancelled' OR [Status]=N'duplicate' OR [Status]=N'skipped' OR [Status]=N'failed' OR [Status]=N'completed' OR [Status]=N'downstream_rebuild_started' OR [Status]=N'procedure_started' OR [Status]=N'converted' OR [Status]=N'staged' OR [Status]=N'started' OR [Status]=N'queued'))
IF EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditBatch_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]'))
ALTER TABLE [dbo].[ImportAuditBatch] CHECK CONSTRAINT [CK_ImportAuditBatch_Status]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditBatch_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]'))
ALTER TABLE [dbo].[ImportAuditBatch] WITH CHECK ADD CONSTRAINT [CK_ImportAuditBatch_DetailsJson] CHECK (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ImportAuditBatch_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ImportAuditBatch]'))
ALTER TABLE [dbo].[ImportAuditBatch] CHECK CONSTRAINT [CK_ImportAuditBatch_DetailsJson]
