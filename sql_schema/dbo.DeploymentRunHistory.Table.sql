SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeploymentRunHistory]') AND type in (N'U'))
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
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DeploymentRunHistory]') AND name = N'IX_DeploymentRunHistory_StartedAtUtc')
CREATE NONCLUSTERED INDEX [IX_DeploymentRunHistory_StartedAtUtc] ON [dbo].[DeploymentRunHistory]
(
    [StartedAtUtc] DESC
)
INCLUDE([Status],[BranchName],[GitCommit],[MigrationCount]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DeploymentRunHistory_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[DeploymentRunHistory]'))
ALTER TABLE [dbo].[DeploymentRunHistory] ADD CONSTRAINT [CK_DeploymentRunHistory_Status] CHECK (([Status]=N'ValidationOnly' OR [Status]=N'Failed' OR [Status]=N'Succeeded' OR [Status]=N'Started'))
