/*
MigrationId: 20260704_001_allow_optional_survey_questions
Purpose: Allow optional questions in the SQL-backed survey framework
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
PostValidationQuery: SELECT cc.name, cc.definition FROM sys.check_constraints cc WHERE cc.name = N'CK_SurveyQuestions_Required' AND cc.parent_object_id = OBJECT_ID(N'dbo.SurveyQuestions', N'U') AND cc.definition LIKE N'%IsRequired%' AND cc.definition LIKE N'%0%' AND cc.definition LIKE N'%1%';
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration relaxes the Phase 7 required-only survey constraint so bot code can explicitly
persist optional questions. The default remains required, preserving existing survey behavior.
Rollback is manual if optional questions have been created; either keep the relaxed constraint or
convert optional rows to required before restoring the old required-only check.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_SurveyQuestions_Required'
      AND parent_object_id = OBJECT_ID(N'dbo.SurveyQuestions', N'U')
)
    ALTER TABLE [dbo].[SurveyQuestions] DROP CONSTRAINT [CK_SurveyQuestions_Required];
GO

IF OBJECT_ID(N'dbo.SurveyQuestions', N'U') IS NOT NULL
    ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Required]
    CHECK ([IsRequired] IN (0, 1));
GO
