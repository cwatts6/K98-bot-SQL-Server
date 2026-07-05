/*
MigrationId: 20260705_001_add_survey_reporting_views
Purpose: Add private survey reporting views and export helper procedure for Survey Export v2
Author: cwatts
CreatedUtc: 2026-07-05
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyPosts', N'U') AS SurveyPostsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.v_SurveyReportingQuestionSummary', N'V') AS QuestionViewObjectId, OBJECT_ID(N'dbo.v_SurveyReportingOptionSummary', N'V') AS OptionViewObjectId, OBJECT_ID(N'dbo.usp_SurveyReporting_ExportV2', N'P') AS ExportProcObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is reporting-only. It adds aggregate survey reporting views and a helper procedure
for private admin/leadership reporting consumers. The views intentionally exclude raw text/detail
answers, per-user answers, and Discord identity fields so they are safe as a dashboard-readiness
contract. Private response-detail exports remain owned by the bot service layer.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
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
           SUM(CASE WHEN RatingValue = 5 THEN 1 ELSE 0 END) AS Rating5Count
    FROM dbo.SurveyRatingAnswers
    GROUP BY SurveyID, SurveyQuestionID
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
    COALESCE(rating.Rating5Count, 0) AS Rating5Count
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
LEFT JOIN RankingStats ranking
  ON ranking.SurveyID = q.SurveyID
 AND ranking.SurveyQuestionID = q.SurveyQuestionID;
GO

CREATE OR ALTER VIEW dbo.v_SurveyReportingOptionSummary
AS
WITH ResponseCounts AS (
    SELECT SurveyID, COUNT_BIG(1) AS TotalResponses
    FROM dbo.SurveyResponses
    GROUP BY SurveyID
),
ChoiceSelections AS (
    SELECT SurveyID, SurveyQuestionID, SurveyOptionID, COUNT_BIG(1) AS SelectionCount
    FROM dbo.SurveyAnswers
    GROUP BY SurveyID, SurveyQuestionID, SurveyOptionID
),
QuestionChoiceTops AS (
    SELECT SurveyID, SurveyQuestionID, MAX(SelectionCount) AS TopSelectionCount
    FROM ChoiceSelections
    GROUP BY SurveyID, SurveyQuestionID
),
RankingStats AS (
    SELECT SurveyID, SurveyQuestionID, SurveyOptionID,
           COUNT_BIG(1) AS RankedCount,
           AVG(CAST(RankValue AS float)) AS AverageRank,
           SUM(CASE WHEN RankValue = 1 THEN 1 ELSE 0 END) AS Rank1Count,
           SUM(CASE WHEN RankValue = 2 THEN 1 ELSE 0 END) AS Rank2Count,
           SUM(CASE WHEN RankValue = 3 THEN 1 ELSE 0 END) AS Rank3Count,
           SUM(CASE WHEN RankValue = 4 THEN 1 ELSE 0 END) AS Rank4Count,
           SUM(CASE WHEN RankValue = 5 THEN 1 ELSE 0 END) AS Rank5Count,
           SUM(CASE WHEN RankValue = 6 THEN 1 ELSE 0 END) AS Rank6Count
    FROM dbo.SurveyRankingAnswers
    GROUP BY SurveyID, SurveyQuestionID, SurveyOptionID
)
SELECT
    p.SurveyID,
    p.Title,
    p.Status,
    p.ResultVisibility,
    q.SurveyQuestionID,
    q.QuestionKey,
    q.Prompt,
    q.QuestionType,
    q.SortOrder AS QuestionSortOrder,
    q.IsRequired,
    o.SurveyOptionID,
    o.OptionKey,
    o.Label AS OptionLabel,
    o.SortOrder AS OptionSortOrder,
    COALESCE(resp.TotalResponses, 0) AS TotalResponses,
    COALESCE(choice_counts.SelectionCount, 0) AS SelectionCount,
    CASE
        WHEN COALESCE(resp.TotalResponses, 0) = 0 THEN CAST(0 AS decimal(9,4))
        ELSE CAST(COALESCE(choice_counts.SelectionCount, 0) AS decimal(19,4))
             / CAST(resp.TotalResponses AS decimal(19,4))
    END AS SelectionRateOfResponses,
    CASE
        WHEN COALESCE(choice_counts.SelectionCount, 0) > 0
         AND choice_counts.SelectionCount = choice_tops.TopSelectionCount THEN 1
        ELSE 0
    END AS IsTopSelection,
    COALESCE(ranking.RankedCount, 0) AS RankedCount,
    ranking.AverageRank,
    COALESCE(ranking.Rank1Count, 0) AS Rank1Count,
    COALESCE(ranking.Rank2Count, 0) AS Rank2Count,
    COALESCE(ranking.Rank3Count, 0) AS Rank3Count,
    COALESCE(ranking.Rank4Count, 0) AS Rank4Count,
    COALESCE(ranking.Rank5Count, 0) AS Rank5Count,
    COALESCE(ranking.Rank6Count, 0) AS Rank6Count
FROM dbo.SurveyPosts p
JOIN dbo.SurveyQuestions q
  ON q.SurveyID = p.SurveyID
JOIN dbo.SurveyQuestionOptions o
  ON o.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN ResponseCounts resp
  ON resp.SurveyID = p.SurveyID
LEFT JOIN ChoiceSelections choice_counts
  ON choice_counts.SurveyID = q.SurveyID
 AND choice_counts.SurveyQuestionID = q.SurveyQuestionID
 AND choice_counts.SurveyOptionID = o.SurveyOptionID
LEFT JOIN QuestionChoiceTops choice_tops
  ON choice_tops.SurveyID = q.SurveyID
 AND choice_tops.SurveyQuestionID = q.SurveyQuestionID
LEFT JOIN RankingStats ranking
  ON ranking.SurveyID = q.SurveyID
 AND ranking.SurveyQuestionID = q.SurveyQuestionID
 AND ranking.SurveyOptionID = o.SurveyOptionID;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SurveyReporting_ExportV2
    @SurveyID bigint
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SurveyID, Title, Status, ResultVisibility, CreatedAtUtc, ClosesAtUtc,
           ClosedAtUtc, ClosedReason,
           SurveyQuestionID, QuestionKey, Prompt, QuestionType, QuestionSortOrder,
           IsRequired, MinSelections, MaxSelections, AllowDetails, TotalResponses,
           OptionCount, AnsweredResponses, SkippedResponses, ChoiceSelectionCount,
           RankedOptionCount, RankingFirstPlaceCount, AverageRating, MinimumRating,
           MaximumRating, Rating1Count, Rating2Count, Rating3Count, Rating4Count,
           Rating5Count
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
