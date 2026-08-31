SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repair_PreKvk_20260828_BadImport_AuditPhase]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Repair_PreKvk_20260828_BadImport_AuditPhase](
	[ImportAuditPhaseId] [bigint] NOT NULL,
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
	[CreatedAtUtc] [datetime2](3) NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
