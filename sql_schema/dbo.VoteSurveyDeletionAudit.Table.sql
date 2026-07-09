SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[VoteSurveyDeletionAudit](
        [DeletionAuditID] [bigint] IDENTITY(1,1) NOT NULL,
        [ContentKind] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [ContentID] [bigint] NOT NULL,
        [Title] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
        [Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [GuildID] [bigint] NOT NULL,
        [ChannelID] [bigint] NOT NULL,
        [MessageID] [bigint] NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [ClosesAtUtc] [datetime2](0) NOT NULL,
        [ClosedAtUtc] [datetime2](0) NULL,
        [DeletedAtUtc] [datetime2](0) NOT NULL,
        [DeletedBy] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
        [Reason] [nvarchar](500) COLLATE Latin1_General_CI_AS NOT NULL,
        [BreakGlassProductionDelete] [bit] NOT NULL,
        [RowCountsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
        [LocalAuditSummaryJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
        CONSTRAINT [PK_VoteSurveyDeletionAudit] PRIMARY KEY CLUSTERED ([DeletionAuditID] ASC)
    )
END

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VoteSurveyDeletionAudit_DeletedAtUtc')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] ADD CONSTRAINT [DF_VoteSurveyDeletionAudit_DeletedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [DeletedAtUtc]

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_ContentKind')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_ContentKind] CHECK ([ContentKind] IN ('Vote', 'Survey'))

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_Reason')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_Reason] CHECK (LEN(LTRIM(RTRIM([Reason]))) BETWEEN 1 AND 500)

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_DeletedBy')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_DeletedBy] CHECK (LEN(LTRIM(RTRIM([DeletedBy]))) BETWEEN 1 AND 128)

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_RowCountsJson')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_RowCountsJson] CHECK (ISJSON([RowCountsJson]) = 1)

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson] CHECK ([LocalAuditSummaryJson] IS NULL OR ISJSON([LocalAuditSummaryJson]) = 1)

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]')
      AND name = N'IX_VoteSurveyDeletionAudit_Content'
)
    CREATE NONCLUSTERED INDEX [IX_VoteSurveyDeletionAudit_Content]
    ON [dbo].[VoteSurveyDeletionAudit]([ContentKind], [ContentID], [DeletedAtUtc])
