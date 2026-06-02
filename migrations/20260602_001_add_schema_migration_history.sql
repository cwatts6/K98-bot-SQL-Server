/*
MigrationId: 20260602_001_add_schema_migration_history
Purpose: Add SQL migration tracking table
Author: cwatts
CreatedUtc: 2026-06-02
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
TransactionMode: Auto
RelatedBotPR:
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]')
      AND type = N'U'
)
BEGIN
    CREATE TABLE [dbo].[SchemaMigrationHistory](
        [MigrationId] [nvarchar](255) NOT NULL,
        [MigrationFile] [nvarchar](512) NOT NULL,
        [ChecksumSha256] [nvarchar](64) NOT NULL,
        [AppliedAtUtc] [datetime2](0) NOT NULL,
        [AppliedBy] [nvarchar](255) NULL,
        [MachineName] [nvarchar](255) NULL,
        [GitCommit] [nvarchar](40) NULL,
        [BranchName] [nvarchar](255) NULL,
        [DeploymentId] [uniqueidentifier] NULL,
        [Status] [nvarchar](50) NOT NULL,
        [ErrorMessage] [nvarchar](max) NULL,
        [DurationMs] [int] NULL,
        CONSTRAINT [PK_SchemaMigrationHistory] PRIMARY KEY CLUSTERED
        (
            [MigrationId] ASC
        )
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_SchemaMigrationHistory_Status'
      AND parent_object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]')
)
BEGIN
    ALTER TABLE [dbo].[SchemaMigrationHistory]
    ADD CONSTRAINT [CK_SchemaMigrationHistory_Status]
    CHECK ([Status] IN (N'Pending', N'Applied', N'Failed', N'Skipped'));
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]')
      AND name = N'IX_SchemaMigrationHistory_DeploymentId'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_SchemaMigrationHistory_DeploymentId]
    ON [dbo].[SchemaMigrationHistory]([DeploymentId])
    INCLUDE ([MigrationId], [Status], [AppliedAtUtc]);
END
GO
