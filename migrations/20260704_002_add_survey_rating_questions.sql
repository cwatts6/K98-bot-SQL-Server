/*
MigrationId: 20260704_002_add_survey_rating_questions
Purpose: Add fixed 1-5 rating questions to the SQL-backed survey framework
Author: cwatts
CreatedUtc: 2026-07-04
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyQuestions', N'U') AS SurveyQuestionsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyRatingAnswers', N'U') AS SurveyRatingAnswersObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive to the Phase 7-9A survey framework. Rating questions use a fixed
1-5 scale and dedicated answer storage so existing choice, text, optional-question, reminder,
close, and export behavior remains untouched. Rollback is manual after bot rollout because
dbo.SurveyRatingAnswers may contain user-submitted rating values.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Type')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Type];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Type]
CHECK ([QuestionType] IN ('SingleChoice', 'MultiSelect', 'Text', 'Rating'));
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Cardinality')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Cardinality];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Cardinality]
CHECK (
    (
        [QuestionType] IN ('Text', 'Rating')
        AND [MinSelections] = 0
        AND [MaxSelections] = 0
        AND [AllowDetails] = 0
    )
    OR
    (
        [QuestionType] NOT IN ('Text', 'Rating')
        AND [MinSelections] >= 1
        AND [MaxSelections] >= [MinSelections]
        AND [MaxSelections] <= 6
        AND ([QuestionType] <> 'SingleChoice' OR ([MinSelections] = 1 AND [MaxSelections] = 1))
        AND ([QuestionType] <> 'MultiSelect' OR [MaxSelections] >= 2)
    )
);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]')
      AND name = N'UX_SurveyQuestions_SurveyQuestionType'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_SurveyQuestionType]
    ON [dbo].[SurveyQuestions]([SurveyID], [SurveyQuestionID], [QuestionType]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyRatingAnswers](
        [SurveyRatingAnswerID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [ResponseID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
        [RatingValue] [tinyint] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyRatingAnswers] PRIMARY KEY CLUSTERED ([SurveyRatingAnswerID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingAnswers_QuestionType')
    ALTER TABLE [dbo].[SurveyRatingAnswers] ADD CONSTRAINT [DF_SurveyRatingAnswers_QuestionType] DEFAULT ('Rating') FOR [QuestionType];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingAnswers_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyRatingAnswers] ADD CONSTRAINT [DF_SurveyRatingAnswers_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingAnswers_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyRatingAnswers] ADD CONSTRAINT [DF_SurveyRatingAnswers_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingAnswers_QuestionType')
    ALTER TABLE [dbo].[SurveyRatingAnswers] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingAnswers_QuestionType] CHECK ([QuestionType] = 'Rating');
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingAnswers_Value')
    ALTER TABLE [dbo].[SurveyRatingAnswers] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingAnswers_Value] CHECK ([RatingValue] BETWEEN 1 AND 5);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]')
      AND name = N'UX_SurveyRatingAnswers_ResponseQuestion'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRatingAnswers_ResponseQuestion]
    ON [dbo].[SurveyRatingAnswers]([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]')
      AND name = N'IX_SurveyRatingAnswers_SurveyQuestion'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyRatingAnswers_SurveyQuestion]
    ON [dbo].[SurveyRatingAnswers]([SurveyID], [SurveyQuestionID])
    INCLUDE([ResponseID], [DiscordUserID], [RatingValue]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]')
      AND name = N'IX_SurveyRatingAnswers_Response'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyRatingAnswers_Response]
    ON [dbo].[SurveyRatingAnswers]([ResponseID], [SurveyQuestionID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRatingAnswers_Response')
    ALTER TABLE [dbo].[SurveyRatingAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyRatingAnswers_Response]
    FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
    REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID]);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRatingAnswers_SurveyQuestions')
    ALTER TABLE [dbo].[SurveyRatingAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyRatingAnswers_SurveyQuestions]
    FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
    REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType]);
GO
