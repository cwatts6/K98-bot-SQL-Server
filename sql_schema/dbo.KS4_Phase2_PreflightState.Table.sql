SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_PreflightState]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_PreflightState](
	[RunId] [uniqueidentifier] NOT NULL,
	[ScriptRevision] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[DatabaseName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ServerName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ProductionApproved] [bit] NOT NULL,
	[StartedAtUtc] [datetime2](7) NOT NULL,
	[CompletedAtUtc] [datetime2](7) NULL,
	[ExpiresAtUtc] [datetime2](7) NULL,
	[BackupPath] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[BackupVerified] [bit] NOT NULL,
	[Ks4Rows] [bigint] NULL,
	[Ks5Rows] [bigint] NULL,
	[StagingRows] [bigint] NULL,
	[Ks4MaxScan] [int] NULL,
	[Ks5MaxScan] [int] NULL,
	[ColumnInventoryHash] [varbinary](32) NULL,
	[IndexInventoryHash] [varbinary](32) NULL,
	[StatisticInventoryHash] [varbinary](32) NULL,
	[PermissionInventoryHash] [varbinary](32) NULL,
	[ModuleInventoryHash] [varbinary](32) NULL,
	[Status] [varchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[FailureMessage] [nvarchar](2048) COLLATE Latin1_General_CI_AS NULL,
	[MigrationStartedAtUtc] [datetime2](7) NULL,
	[MigrationCompletedAtUtc] [datetime2](7) NULL,
	[VerifiedAtUtc] [datetime2](7) NULL,
	[RollbackCompletedAtUtc] [datetime2](7) NULL,
	[FinalizedAtUtc] [datetime2](7) NULL,
	[BaselineKs4Digest] [varbinary](32) NULL,
	[BaselineKs5Digest] [varbinary](32) NULL,
	[BaselineStagingDigest] [varbinary](32) NULL,
	[ForwardKs4Digest] [varbinary](32) NULL,
	[ForwardKs5Digest] [varbinary](32) NULL,
	[ForwardStagingDigest] [varbinary](32) NULL,
 CONSTRAINT [PK_KS4_Phase2_PreflightState] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_KS4_Phase2_Preflight_BackupVerified]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[KS4_Phase2_PreflightState] ADD  CONSTRAINT [DF_KS4_Phase2_Preflight_BackupVerified]  DEFAULT ((0)) FOR [BackupVerified]
END

