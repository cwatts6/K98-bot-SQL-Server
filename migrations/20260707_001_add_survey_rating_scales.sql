/*
MigrationId: 20260707_001_add_survey_rating_scales
Purpose: Add configurable rating scales, scale labels, and named rating values to survey ratings
Author: cwatts
CreatedUtc: 2026-07-07
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyQuestions', N'U') AS SurveyQuestionsObjectId, OBJECT_ID(N'dbo.SurveyRatingAnswers', N'U') AS SurveyRatingAnswersObjectId;
PostValidationQuery: SELECT COL_LENGTH(N'dbo.SurveyQuestions', N'RatingMinValue') AS RatingMinValueColumn, OBJECT_ID(N'dbo.SurveyRatingChoiceLabels', N'U') AS RatingLabelsObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive for existing fixed 1-5 rating questions. Existing rating questions and
answers keep their default 1-5 scale. The rating answer check constraint is widened to 1-10, while
bot-side validation and SurveyQuestions metadata define the exact allowed scale for each question.
Rollback is manual after bot rollout because extended rating questions may contain 6-10 answers or
custom scale metadata.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'dbo.SurveyQuestions', N'RatingMinValue') IS NULL
    ALTER TABLE [dbo].[SurveyQuestions]
    ADD [RatingMinValue] [tinyint] NOT NULL
        CONSTRAINT [DF_SurveyQuestions_RatingMinValue] DEFAULT (1);
GO

IF COL_LENGTH(N'dbo.SurveyQuestions', N'RatingMaxValue') IS NULL
    ALTER TABLE [dbo].[SurveyQuestions]
    ADD [RatingMaxValue] [tinyint] NOT NULL
        CONSTRAINT [DF_SurveyQuestions_RatingMaxValue] DEFAULT (5);
GO

IF COL_LENGTH(N'dbo.SurveyQuestions', N'RatingLowLabel') IS NULL
    ALTER TABLE [dbo].[SurveyQuestions]
    ADD [RatingLowLabel] [nvarchar](40) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.SurveyQuestions', N'RatingHighLabel') IS NULL
    ALTER TABLE [dbo].[SurveyQuestions]
    ADD [RatingHighLabel] [nvarchar](40) COLLATE Latin1_General_CI_AS NULL;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_RatingScale')
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_RatingScale];
GO

ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_RatingScale]
CHECK (
    (
        [QuestionType] = 'Rating'
        AND [RatingMinValue] BETWEEN 1 AND 9
        AND [RatingMaxValue] BETWEEN 2 AND 10
        AND [RatingMaxValue] > [RatingMinValue]
    )
    OR
    (
        [QuestionType] <> 'Rating'
        AND [RatingMinValue] = 1
        AND [RatingMaxValue] = 5
        AND [RatingLowLabel] IS NULL
        AND [RatingHighLabel] IS NULL
    )
);
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

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingAnswers_Value')
    ALTER TABLE [dbo].[SurveyRatingAnswers] DROP CONSTRAINT [CK_SurveyRatingAnswers_Value];
GO

ALTER TABLE [dbo].[SurveyRatingAnswers] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingAnswers_Value]
CHECK ([RatingValue] BETWEEN 1 AND 10);
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyRatingChoiceLabels](
        [SurveyRatingChoiceLabelID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
        [RatingValue] [tinyint] NOT NULL,
        [Label] [nvarchar](80) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyRatingChoiceLabels] PRIMARY KEY CLUSTERED ([SurveyRatingChoiceLabelID] ASC)
    );
END;
GO

IF COL_LENGTH(N'dbo.SurveyRatingChoiceLabels', N'QuestionType') IS NULL
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels]
    ADD [QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL
        CONSTRAINT [DF_SurveyRatingChoiceLabels_QuestionType] DEFAULT ('Rating');
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingChoiceLabels_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD CONSTRAINT [DF_SurveyRatingChoiceLabels_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingChoiceLabels_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD CONSTRAINT [DF_SurveyRatingChoiceLabels_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyRatingChoiceLabels_QuestionType')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD CONSTRAINT [DF_SurveyRatingChoiceLabels_QuestionType] DEFAULT ('Rating') FOR [QuestionType];
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingChoiceLabels_Value')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingChoiceLabels_Value] CHECK ([RatingValue] BETWEEN 1 AND 10);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingChoiceLabels_Label')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingChoiceLabels_Label] CHECK (LEN(LTRIM(RTRIM([Label]))) BETWEEN 1 AND 80);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyRatingChoiceLabels_QuestionType')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] WITH CHECK ADD CONSTRAINT [CK_SurveyRatingChoiceLabels_QuestionType] CHECK ([QuestionType] = 'Rating');
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]')
      AND name = N'UX_SurveyQuestions_SurveyQuestion'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_SurveyQuestion]
    ON [dbo].[SurveyQuestions]([SurveyID], [SurveyQuestionID]);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]')
      AND name = N'UX_SurveyRatingChoiceLabels_QuestionValue'
)
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRatingChoiceLabels_QuestionValue]
    ON [dbo].[SurveyRatingChoiceLabels]([SurveyID], [SurveyQuestionID], [RatingValue]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyRatingChoiceLabels_Questions')
    ALTER TABLE [dbo].[SurveyRatingChoiceLabels] WITH CHECK ADD CONSTRAINT [FK_SurveyRatingChoiceLabels_Questions]
    FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
    REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType]);
GO

CREATE OR ALTER VIEW dbo.v_SurveyReportingQuestionSummary
AS
WITH ResponseCounts AS (
    SELECT SurveyID, COUNT_BIG(1) AS TotalResponses
    FROM dbo.SurveyResponses
    GROUP BY SurveyID
),
OptionCounts AS (
    SELECT q.SurveyID, q.SurveyQuestionID, COUNT_BIG(o.SurveyOptionID) AS OptionCount
    FROM dbo.SurveyQuestions q
    LEFT JOIN dbo.SurveyQuestionOptions o
      ON o.SurveyQuestionID = q.SurveyQuestionID
    GROUP BY q.SurveyID, q.SurveyQuestionID
),
ChoiceAnswered AS (
    SELECT SurveyID, SurveyQuestionID, COUNT_BIG(1) AS AnsweredResponses
    FROM (
        SELECT DISTINCT SurveyID, SurveyQuestionID, ResponseID
        FROM dbo.SurveyAnswers
    ) answered
    GROUP BY SurveyID, SurveyQuestionID
),
ChoiceSelections AS (
    SELECT SurveyID, SurveyQuestionID, COUNT_BIG(1) AS SelectionCount
    FROM dbo.SurveyAnswers
    GROUP BY SurveyID, SurveyQuestionID
),
TextAnswered AS (
    SELECT SurveyID, SurveyQuestionID, COUNT_BIG(1) AS AnsweredResponses
    FROM dbo.SurveyTextAnswers
    GROUP BY SurveyID, SurveyQuestionID
),
RatingStats AS (
    SELECT SurveyID, SurveyQuestionID,
           COUNT_BIG(1) AS AnsweredResponses,
           AVG(CAST(RatingValue AS float)) AS AverageRating,
           MIN(RatingValue) AS MinimumRating,
           MAX(RatingValue) AS MaximumRating,
           SUM(CASE WHEN RatingValue = 1 THEN 1 ELSE 0 END) AS Rating1Count,
           SUM(CASE WHEN RatingValue = 2 THEN 1 ELSE 0 END) AS Rating2Count,
           SUM(CASE WHEN RatingValue = 3 THEN 1 ELSE 0 END) AS Rating3Count,
           SUM(CASE WHEN RatingValue = 4 THEN 1 ELSE 0 END) AS Rating4Count,
           SUM(CASE WHEN RatingValue = 5 THEN 1 ELSE 0 END) AS Rating5Count,
           SUM(CASE WHEN RatingValue = 6 THEN 1 ELSE 0 END) AS Rating6Count,
           SUM(CASE WHEN RatingValue = 7 THEN 1 ELSE 0 END) AS Rating7Count,
           SUM(CASE WHEN RatingValue = 8 THEN 1 ELSE 0 END) AS Rating8Count,
           SUM(CASE WHEN RatingValue = 9 THEN 1 ELSE 0 END) AS Rating9Count,
           SUM(CASE WHEN RatingValue = 10 THEN 1 ELSE 0 END) AS Rating10Count
    FROM dbo.SurveyRatingAnswers
    GROUP BY SurveyID, SurveyQuestionID
),
RatingLabels AS (
    SELECT label_questions.SurveyID, label_questions.SurveyQuestionID,
           STUFF((
               SELECT '; ' + CONVERT(varchar(3), l2.RatingValue) + '=' + l2.Label
               FROM dbo.SurveyRatingChoiceLabels l2
               WHERE l2.SurveyID = label_questions.SurveyID
                 AND l2.SurveyQuestionID = label_questions.SurveyQuestionID
               ORDER BY l2.RatingValue ASC
               FOR XML PATH(''), TYPE
           ).value('.', 'nvarchar(max)'), 1, 2, '') AS RatingLabels
    FROM (
        SELECT DISTINCT SurveyID, SurveyQuestionID
        FROM dbo.SurveyRatingChoiceLabels
    ) label_questions
),
RatingDistributionQuestions AS (
    SELECT q.SurveyID, q.SurveyQuestionID, q.RatingMinValue, q.RatingMaxValue
    FROM dbo.SurveyQuestions q
    WHERE q.QuestionType = 'Rating'
),
RatingDistribution AS (
    SELECT q.SurveyID, q.SurveyQuestionID,
           STUFF((
               SELECT ' ' + COALESCE(l.Label, CONVERT(varchar(3), v.RatingValue)) + ':' + CONVERT(varchar(20), COUNT_BIG(a.SurveyRatingAnswerID))
               FROM (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) v(RatingValue)
               LEFT JOIN dbo.SurveyRatingAnswers a
                 ON a.SurveyID = q.SurveyID
                AND a.SurveyQuestionID = q.SurveyQuestionID
                AND a.RatingValue = v.RatingValue
               LEFT JOIN dbo.SurveyRatingChoiceLabels l
                 ON l.SurveyID = q.SurveyID
                AND l.SurveyQuestionID = q.SurveyQuestionID
                AND l.RatingValue = v.RatingValue
               WHERE v.RatingValue BETWEEN q.RatingMinValue AND q.RatingMaxValue
               GROUP BY v.RatingValue, l.Label
               ORDER BY v.RatingValue ASC
               FOR XML PATH(''), TYPE
           ).value('.', 'nvarchar(max)'), 1, 1, '') AS RatingDistribution
    FROM RatingDistributionQuestions q
),
RankingStats AS (
    SELECT SurveyID, SurveyQuestionID,
           COUNT_BIG(DISTINCT ResponseID) AS AnsweredResponses,
           COUNT_BIG(1) AS RankedOptionCount,
           SUM(CASE WHEN RankValue = 1 THEN 1 ELSE 0 END) AS FirstPlaceCount
    FROM dbo.SurveyRankingAnswers
    GROUP BY SurveyID, SurveyQuestionID
)
SELECT
    p.SurveyID,
    p.Title,
    p.Status,
    p.ResultVisibility,
    p.CreatedAtUtc,
    p.ClosesAtUtc,
    p.ClosedAtUtc,
    p.ClosedReason,
    q.SurveyQuestionID,
    q.QuestionKey,
    q.Prompt,
    q.QuestionType,
    q.SortOrder AS QuestionSortOrder,
    q.IsRequired,
    q.MinSelections,
    q.MaxSelections,
    q.AllowDetails,
    q.RatingMinValue,
    q.RatingMaxValue,
    q.RatingLowLabel,
    q.RatingHighLabel,
    COALESCE(rating_labels.RatingLabels, '') AS RatingLabels,
    COALESCE(rating_distribution.RatingDistribution, '') AS RatingDistribution,
    COALESCE(resp.TotalResponses, 0) AS TotalResponses,
    COALESCE(opt.OptionCount, 0) AS OptionCount,
    COALESCE(
        CASE
            WHEN q.QuestionType = 'Text' THEN text_answers.AnsweredResponses
            WHEN q.QuestionType = 'Rating' THEN rating.AnsweredResponses
            WHEN q.QuestionType = 'Ranking' THEN ranking.AnsweredResponses
            ELSE choice_answers.AnsweredResponses
        END,
        0
    ) AS AnsweredResponses,
    COALESCE(resp.TotalResponses, 0) - COALESCE(
        CASE
            WHEN q.QuestionType = 'Text' THEN text_answers.AnsweredResponses
            WHEN q.QuestionType = 'Rating' THEN rating.AnsweredResponses
            WHEN q.QuestionType = 'Ranking' THEN ranking.AnsweredResponses
            ELSE choice_answers.AnsweredResponses
        END,
        0
    ) AS SkippedResponses,
    COALESCE(choice_selections.SelectionCount, 0) AS ChoiceSelectionCount,
    COALESCE(ranking.RankedOptionCount, 0) AS RankedOptionCount,
    COALESCE(ranking.FirstPlaceCount, 0) AS RankingFirstPlaceCount,
    rating.AverageRating,
    rating.MinimumRating,
    rating.MaximumRating,
    COALESCE(rating.Rating1Count, 0) AS Rating1Count,
    COALESCE(rating.Rating2Count, 0) AS Rating2Count,
    COALESCE(rating.Rating3Count, 0) AS Rating3Count,
    COALESCE(rating.Rating4Count, 0) AS Rating4Count,
    COALESCE(rating.Rating5Count, 0) AS Rating5Count,
    COALESCE(rating.Rating6Count, 0) AS Rating6Count,
    COALESCE(rating.Rating7Count, 0) AS Rating7Count,
    COALESCE(rating.Rating8Count, 0) AS Rating8Count,
    COALESCE(rating.Rating9Count, 0) AS Rating9Count,
    COALESCE(rating.Rating10Count, 0) AS Rating10Count
FROM dbo.SurveyPosts p
JOIN dbo.SurveyQuestions q
  ON q.SurveyID = p.SurveyID
LEFT JOIN ResponseCounts resp
  ON resp.SurveyID = p.SurveyID
LEFT JOIN OptionCounts opt
  ON opt.SurveyID = q.SurveyID
 AND opt.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN ChoiceAnswered choice_answers
  ON choice_answers.SurveyID = q.SurveyID
 AND choice_answers.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN ChoiceSelections choice_selections
  ON choice_selections.SurveyID = q.SurveyID
 AND choice_selections.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN TextAnswered text_answers
  ON text_answers.SurveyID = q.SurveyID
 AND text_answers.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN RatingStats rating
  ON rating.SurveyID = q.SurveyID
 AND rating.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN RatingLabels rating_labels
  ON rating_labels.SurveyID = q.SurveyID
 AND rating_labels.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN RatingDistribution rating_distribution
  ON rating_distribution.SurveyID = q.SurveyID
 AND rating_distribution.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN RankingStats ranking
  ON ranking.SurveyID = q.SurveyID
 AND ranking.SurveyQuestionID = q.SurveyQuestionID;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SurveyReporting_ExportV2
    @SurveyID bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SurveyID, Title, Status, ResultVisibility, CreatedAtUtc, ClosesAtUtc,
           ClosedAtUtc, ClosedReason,
           SurveyQuestionID, QuestionKey, Prompt, QuestionType, QuestionSortOrder,
           IsRequired, MinSelections, MaxSelections, AllowDetails,
           RatingMinValue, RatingMaxValue, RatingLowLabel, RatingHighLabel,
           RatingLabels, RatingDistribution,
           TotalResponses, OptionCount, AnsweredResponses, SkippedResponses,
           ChoiceSelectionCount, RankedOptionCount, RankingFirstPlaceCount,
           AverageRating, MinimumRating, MaximumRating,
           Rating1Count, Rating2Count, Rating3Count, Rating4Count, Rating5Count,
           Rating6Count, Rating7Count, Rating8Count, Rating9Count, Rating10Count
    FROM dbo.v_SurveyReportingQuestionSummary
    WHERE SurveyID = @SurveyID
    ORDER BY QuestionSortOrder ASC, SurveyQuestionID ASC;

    SELECT SurveyID, Title, Status, ResultVisibility,
           SurveyQuestionID, QuestionKey, Prompt, QuestionType, QuestionSortOrder,
           IsRequired, SurveyOptionID, OptionKey, OptionLabel, OptionSortOrder,
           TotalResponses, SelectionCount, SelectionRateOfResponses, IsTopSelection,
           RankedCount, AverageRank, Rank1Count, Rank2Count, Rank3Count, Rank4Count,
           Rank5Count, Rank6Count
    FROM dbo.v_SurveyReportingOptionSummary
    WHERE SurveyID = @SurveyID
    ORDER BY QuestionSortOrder ASC, OptionSortOrder ASC, SurveyOptionID ASC;
END;
GO

