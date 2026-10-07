SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_SurveyReportingOptionSummary]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_SurveyReportingOptionSummary]  AS 
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


'
