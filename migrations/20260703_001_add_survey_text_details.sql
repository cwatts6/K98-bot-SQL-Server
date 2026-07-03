/*
MigrationId: 20260703_001_add_survey_text_details
Purpose: Add free-text survey answers and selected-choice detail notes
Author: cwatts
CreatedUtc: 2026-07-03
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyPosts', N'U') AS SurveyPostsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyTextAnswers', N'U') AS SurveyTextAnswersObjectId, OBJECT_ID(N'dbo.SurveyAnswerDetails', N'U') AS SurveyAnswerDetailsObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive to the Phase 7 survey framework. Existing choice-only survey
responses remain in dbo.SurveyAnswers. Free-text answers and optional selected-choice detail
notes are stored in separate tables so existing aggregate choice behavior remains untouched.
Rollback is manual because these tables may contain user-submitted text after bot rollout.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'dbo.SurveyQuestions', N'AllowDetails') IS NULL
BEGIN
    ALTER TABLE [dbo].[SurveyQuestions]
        ADD [AllowDetails] [bit] NOT NULL
            CONSTRAINT [DF_SurveyQuestions_AllowDetails] DEFAULT ((0));
END;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Type')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Type];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Type]
CHECK ([QuestionType] IN ('SingleChoice', 'MultiSelect', 'Text'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Cardinality')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Cardinality];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Cardinality]
CHECK (
    (
        [QuestionType] = 'Text'
        AND [MinSelections] = 0
        AND [MaxSelections] = 0
        AND [AllowDetails] = 0
    )
    OR
    (
        [QuestionType] <> 'Text'
        AND [MinSelections] >= 1
        AND [MaxSelections] >= [MinSelections]
        AND [MaxSelections] <= 6
        AND ([QuestionType] <> 'SingleChoice' OR ([MinSelections] = 1 AND [MaxSelections] = 1))
        AND ([QuestionType] <> 'MultiSelect' OR [MaxSelections] >= 2)
    )
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyTextAnswers](
        [SurveyID] [bigint] NOT NULL,
        [ResponseID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [AnswerText] [nvarchar](500) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyTextAnswers] PRIMARY KEY CLUSTERED ([SurveyID] ASC, [DiscordUserID] ASC, [SurveyQuestionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyAnswerDetails](
        [SurveyID] [bigint] NOT NULL,
        [ResponseID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [SurveyOptionID] [bigint] NOT NULL,
        [DetailText] [nvarchar](300) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyAnswerDetails] PRIMARY KEY CLUSTERED ([SurveyID] ASC, [DiscordUserID] ASC, [SurveyQuestionID] ASC, [SurveyOptionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyTextAnswers_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyTextAnswers] ADD CONSTRAINT [DF_SurveyTextAnswers_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyTextAnswers_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyTextAnswers] ADD CONSTRAINT [DF_SurveyTextAnswers_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyAnswerDetails_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyAnswerDetails] ADD CONSTRAINT [DF_SurveyAnswerDetails_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyAnswerDetails_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyAnswerDetails] ADD CONSTRAINT [DF_SurveyAnswerDetails_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]') AND name = N'UX_SurveyAnswers_ResponseOption')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyAnswers_ResponseOption] ON [dbo].[SurveyAnswers]([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID]);
GO

IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswerDetails_Answers')
    ALTER TABLE [dbo].[SurveyAnswerDetails] DROP CONSTRAINT [FK_SurveyAnswerDetails_Answers];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyTextAnswers_Response')
    ALTER TABLE [dbo].[SurveyTextAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyTextAnswers_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID]) REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyTextAnswers_SurveyQuestions')
    ALTER TABLE [dbo].[SurveyTextAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyTextAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID]) REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswerDetails_Response')
    ALTER TABLE [dbo].[SurveyAnswerDetails] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswerDetails_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID]) REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswerDetails_Answers')
    ALTER TABLE [dbo].[SurveyAnswerDetails] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswerDetails_Answers] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID]) REFERENCES [dbo].[SurveyAnswers] ([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]') AND name = N'IX_SurveyTextAnswers_Response')
    CREATE NONCLUSTERED INDEX [IX_SurveyTextAnswers_Response] ON [dbo].[SurveyTextAnswers]([ResponseID], [SurveyQuestionID]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]') AND name = N'IX_SurveyAnswerDetails_Response')
    CREATE NONCLUSTERED INDEX [IX_SurveyAnswerDetails_Response] ON [dbo].[SurveyAnswerDetails]([ResponseID], [SurveyQuestionID], [SurveyOptionID]);
GO
