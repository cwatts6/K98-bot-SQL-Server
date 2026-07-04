/*
MigrationId: 20260704_003_add_survey_ranking_questions
Purpose: Add complete ranking questions to the SQL-backed survey framework
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
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyRankingAnswers', N'U') AS SurveyRankingAnswersObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive to the Phase 7-9B survey framework. Ranking questions reuse
dbo.SurveyQuestionOptions as rankable items and store one submitted row per ranked option in
dbo.SurveyRankingAnswers. Existing choice, text, rating, optional-question, reminder, close, and
export behavior remains untouched. Rollback is manual after bot rollout because
dbo.SurveyRankingAnswers may contain user-submitted ranking values.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Type')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Type];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Type]
CHECK ([QuestionType] IN ('SingleChoice', 'MultiSelect', 'Text', 'Rating', 'Ranking'));
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
        [QuestionType] = 'Ranking'
        AND [MinSelections] >= 2
        AND [MaxSelections] = [MinSelections]
        AND [MaxSelections] <= 6
        AND [AllowDetails] = 0
    )
    OR
    (
        [QuestionType] NOT IN ('Text', 'Rating', 'Ranking')
        AND [MinSelections] >= 1
        AND [MaxSelections] >= [MinSelections]
        AND [MaxSelections] <= 6
        AND ([QuestionType] <> 'SingleChoice' OR ([MinSelections] = 1 AND [MaxSelections] = 1))
        AND ([QuestionType] <> 'MultiSelect' OR [MaxSelections] >= 2)
    )
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyRankingAnswers](
        [SurveyRankingAnswerID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [ResponseID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [SurveyOptionID] [bigint] NOT NULL,
        [QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
        [RankValue] [tinyint] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyRankingAnswers] PRIMARY KEY CLUSTERED ([SurveyRankingAnswerID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRankingAnswers_QuestionType')
    ALTER TABLE [dbo].[SurveyRankingAnswers] ADD CONSTRAINT [DF_SurveyRankingAnswers_QuestionType] DEFAULT ('Ranking') FOR [QuestionType];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRankingAnswers_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyRankingAnswers] ADD CONSTRAINT [DF_SurveyRankingAnswers_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRankingAnswers_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyRankingAnswers] ADD CONSTRAINT [DF_SurveyRankingAnswers_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRankingAnswers_QuestionType')
    ALTER TABLE [dbo].[SurveyRankingAnswers] WITH CHECK ADD CONSTRAINT [CK_SurveyRankingAnswers_QuestionType] CHECK ([QuestionType] = 'Ranking');
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRankingAnswers_RankValue')
    ALTER TABLE [dbo].[SurveyRankingAnswers] WITH CHECK ADD CONSTRAINT [CK_SurveyRankingAnswers_RankValue] CHECK ([RankValue] BETWEEN 1 AND 6);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]')
      AND name = N'UX_SurveyRankingAnswers_ResponseQuestionOption'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRankingAnswers_ResponseQuestionOption]
    ON [dbo].[SurveyRankingAnswers]([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]')
      AND name = N'UX_SurveyRankingAnswers_ResponseQuestionRank'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRankingAnswers_ResponseQuestionRank]
    ON [dbo].[SurveyRankingAnswers]([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [RankValue]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]')
      AND name = N'IX_SurveyRankingAnswers_SurveyQuestion'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyRankingAnswers_SurveyQuestion]
    ON [dbo].[SurveyRankingAnswers]([SurveyID], [SurveyQuestionID])
    INCLUDE([ResponseID], [DiscordUserID], [SurveyOptionID], [RankValue]);

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]')
      AND name = N'IX_SurveyRankingAnswers_Response'
)
    CREATE NONCLUSTERED INDEX [IX_SurveyRankingAnswers_Response]
    ON [dbo].[SurveyRankingAnswers]([ResponseID], [SurveyQuestionID], [RankValue]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRankingAnswers_Response')
    ALTER TABLE [dbo].[SurveyRankingAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyRankingAnswers_Response]
    FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
    REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID]);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRankingAnswers_SurveyQuestions')
    ALTER TABLE [dbo].[SurveyRankingAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyRankingAnswers_SurveyQuestions]
    FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
    REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType]);

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRankingAnswers_QuestionOptions')
    ALTER TABLE [dbo].[SurveyRankingAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyRankingAnswers_QuestionOptions]
    FOREIGN KEY([SurveyQuestionID], [SurveyOptionID])
    REFERENCES [dbo].[SurveyQuestionOptions] ([SurveyQuestionID], [SurveyOptionID]);
GO
