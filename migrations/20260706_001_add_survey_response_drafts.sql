/*
MigrationId: 20260706_001_add_survey_response_drafts
Purpose: Add SQL-backed respondent survey draft storage
Author: cwatts
CreatedUtc: 2026-07-06
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyResponseDrafts', N'U') AS SurveyResponseDraftsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyResponseDrafts', N'U') AS SurveyResponseDraftsObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive to the submitted survey response framework. Draft payloads are stored
separately from dbo.SurveyResponses and submitted answer tables so public result cards, private
status summaries, exports, report bundles, and dashboard-safe reporting continue to count only
final submitted responses. Rollback is manual after bot rollout because dbo.SurveyResponseDrafts
may contain unsubmitted respondent text, detail, rating, ranking, and choice payloads.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]')
      AND type = N'U'
)
BEGIN
    CREATE TABLE [dbo].[SurveyResponseDrafts](
        [DraftID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [DraftPayloadJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
        [Revision] [int] NOT NULL,
        [Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        [ExpiresAtUtc] [datetime2](0) NULL,
        CONSTRAINT [PK_SurveyResponseDrafts] PRIMARY KEY CLUSTERED ([DraftID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponseDrafts_Revision')
    ALTER TABLE [dbo].[SurveyResponseDrafts] ADD CONSTRAINT [DF_SurveyResponseDrafts_Revision] DEFAULT ((1)) FOR [Revision];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponseDrafts_Status')
    ALTER TABLE [dbo].[SurveyResponseDrafts] ADD CONSTRAINT [DF_SurveyResponseDrafts_Status] DEFAULT ('Active') FOR [Status];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponseDrafts_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyResponseDrafts] ADD CONSTRAINT [DF_SurveyResponseDrafts_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponseDrafts_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyResponseDrafts] ADD CONSTRAINT [DF_SurveyResponseDrafts_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]')
      AND name = N'UX_SurveyResponseDrafts_User'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyResponseDrafts_User]
    ON [dbo].[SurveyResponseDrafts]([SurveyID], [DiscordUserID]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]')
      AND name = N'IX_SurveyResponseDrafts_Updated'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyResponseDrafts_Updated]
    ON [dbo].[SurveyResponseDrafts]([Status], [UpdatedAtUtc])
    INCLUDE([SurveyID], [DiscordUserID], [ExpiresAtUtc], [Revision]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]')
      AND name = N'IX_SurveyResponseDrafts_Expiry'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyResponseDrafts_Expiry]
    ON [dbo].[SurveyResponseDrafts]([Status], [ExpiresAtUtc])
    INCLUDE([SurveyID], [DiscordUserID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyResponseDrafts_SurveyPosts')
    ALTER TABLE [dbo].[SurveyResponseDrafts] WITH CHECK ADD CONSTRAINT [FK_SurveyResponseDrafts_SurveyPosts]
    FOREIGN KEY([SurveyID]) REFERENCES [dbo].[SurveyPosts] ([SurveyID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyResponseDrafts_Status')
    ALTER TABLE [dbo].[SurveyResponseDrafts] WITH CHECK ADD CONSTRAINT [CK_SurveyResponseDrafts_Status]
    CHECK ([Status] IN ('Active', 'Expired'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyResponseDrafts_Revision')
    ALTER TABLE [dbo].[SurveyResponseDrafts] WITH CHECK ADD CONSTRAINT [CK_SurveyResponseDrafts_Revision]
    CHECK ([Revision] >= 1);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyResponseDrafts_ExpiredAt')
    ALTER TABLE [dbo].[SurveyResponseDrafts] WITH CHECK ADD CONSTRAINT [CK_SurveyResponseDrafts_ExpiredAt]
    CHECK ([Status] <> 'Expired' OR [ExpiresAtUtc] IS NOT NULL);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyResponseDrafts_PayloadJson')
    ALTER TABLE [dbo].[SurveyResponseDrafts] WITH CHECK ADD CONSTRAINT [CK_SurveyResponseDrafts_PayloadJson]
    CHECK (ISJSON([DraftPayloadJson]) = 1);
GO
