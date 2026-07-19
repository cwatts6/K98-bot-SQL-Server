SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_SurveyReportingQuestionSummary]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_SurveyReportingQuestionSummary]  AS 
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
               SELECT ''; '' + CONVERT(varchar(3), l2.RatingValue) + ''='' + l2.Label
               FROM dbo.SurveyRatingChoiceLabels l2
               WHERE l2.SurveyID = label_questions.SurveyID
                 AND l2.SurveyQuestionID = label_questions.SurveyQuestionID
               ORDER BY l2.RatingValue ASC
               FOR XML PATH(''''), TYPE
           ).value(''.'', ''nvarchar(max)''), 1, 2, '''') AS RatingLabels
    FROM (
        SELECT DISTINCT SurveyID, SurveyQuestionID
        FROM dbo.SurveyRatingChoiceLabels
    ) label_questions
),
RatingDistributionQuestions AS (
    SELECT q.SurveyID, q.SurveyQuestionID, q.RatingMinValue, q.RatingMaxValue
    FROM dbo.SurveyQuestions q
    WHERE q.QuestionType = ''Rating''
),
RatingDistribution AS (
    SELECT q.SurveyID, q.SurveyQuestionID,
           STUFF((
               SELECT '' '' + COALESCE(l.Label, CONVERT(varchar(3), v.RatingValue)) + '':'' + CONVERT(varchar(20), COUNT_BIG(a.SurveyRatingAnswerID))
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
               FOR XML PATH(''''), TYPE
           ).value(''.'', ''nvarchar(max)''), 1, 1, '''') AS RatingDistribution
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
    COALESCE(rating_labels.RatingLabels, '''') AS RatingLabels,
    COALESCE(rating_distribution.RatingDistribution, '''') AS RatingDistribution,
    COALESCE(resp.TotalResponses, 0) AS TotalResponses,
    COALESCE(opt.OptionCount, 0) AS OptionCount,
    COALESCE(
        CASE
            WHEN q.QuestionType = ''Text'' THEN text_answers.AnsweredResponses
            WHEN q.QuestionType = ''Rating'' THEN rating.AnsweredResponses
            WHEN q.QuestionType = ''Ranking'' THEN ranking.AnsweredResponses
            ELSE choice_answers.AnsweredResponses
        END,
        0
    ) AS AnsweredResponses,
    COALESCE(resp.TotalResponses, 0) - COALESCE(
        CASE
            WHEN q.QuestionType = ''Text'' THEN text_answers.AnsweredResponses
            WHEN q.QuestionType = ''Rating'' THEN rating.AnsweredResponses
            WHEN q.QuestionType = ''Ranking'' THEN ranking.AnsweredResponses
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


'
