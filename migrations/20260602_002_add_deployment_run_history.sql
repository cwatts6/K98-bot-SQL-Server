/*
MigrationId: 20260602_002_add_deployment_run_history
Purpose: Add SQL deployment run tracking table
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
    WHERE object_id = OBJECT_ID(N'[dbo].[DeploymentRunHistory]')
      AND type = N'U'
)
BEGIN
    CREATE TABLE [dbo].[DeploymentRunHistory](
        [DeploymentId] [uniqueidentifier] NOT NULL,
        [StartedAtUtc] [datetime2](0) NOT NULL,
        [FinishedAtUtc] [datetime2](0) NULL,
        [StartedBy] [nvarchar](255) NULL,
        [MachineName] [nvarchar](255) NULL,
        [DatabaseName] [nvarchar](255) NULL,
        [GitCommit] [nvarchar](40) NULL,
        [BranchName] [nvarchar](255) NULL,
        [MigrationCount] [int] NOT NULL,
        [Status] [nvarchar](50) NOT NULL,
        [ErrorMessage] [nvarchar](max) NULL,
        [DurationSeconds] [int] NULL,
        CONSTRAINT [PK_DeploymentRunHistory] PRIMARY KEY CLUSTERED
        (
            [DeploymentId] ASC
        )
    );
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_DeploymentRunHistory_Status'
)
BEGIN
    ALTER TABLE [dbo].[DeploymentRunHistory]
    ADD CONSTRAINT [CK_DeploymentRunHistory_Status]
    CHECK ([Status] IN (N'Started', N'Succeeded', N'Failed', N'ValidationOnly'));
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[DeploymentRunHistory]')
      AND name = N'IX_DeploymentRunHistory_StartedAtUtc'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_DeploymentRunHistory_StartedAtUtc]
    ON [dbo].[DeploymentRunHistory]([StartedAtUtc] DESC)
    INCLUDE ([Status], [BranchName], [GitCommit], [MigrationCount]);
END
GO
