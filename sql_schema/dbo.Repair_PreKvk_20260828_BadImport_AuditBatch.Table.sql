SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repair_PreKvk_20260828_BadImport_AuditBatch]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Repair_PreKvk_20260828_BadImport_AuditBatch](
	[ImportAuditBatchId] [bigint] NOT NULL,
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
	[UpdatedAtUtc] [datetime2](3) NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
