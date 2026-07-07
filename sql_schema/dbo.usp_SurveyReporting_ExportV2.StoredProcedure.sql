SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_SurveyReporting_ExportV2]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_SurveyReporting_ExportV2] AS' 
END
ALTER PROCEDURE [dbo].[usp_SurveyReporting_ExportV2]
	@SurveyID [bigint]
WITH EXECUTE AS CALLER
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

