SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]') AND type in (N'U'))
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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]') AND name = N'IX_SchemaMigrationHistory_DeploymentId')
CREATE NONCLUSTERED INDEX [IX_SchemaMigrationHistory_DeploymentId] ON [dbo].[SchemaMigrationHistory]
(
    [DeploymentId] ASC
)
INCLUDE([MigrationId],[Status],[AppliedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SchemaMigrationHistory_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[SchemaMigrationHistory]'))
ALTER TABLE [dbo].[SchemaMigrationHistory] ADD CONSTRAINT [CK_SchemaMigrationHistory_Status] CHECK (([Status]=N'Skipped' OR [Status]=N'Failed' OR [Status]=N'Applied' OR [Status]=N'Pending'))
