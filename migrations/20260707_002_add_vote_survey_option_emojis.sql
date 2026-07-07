/*
MigrationId: 20260707_002_add_vote_survey_option_emojis
Purpose: Add optional emoji/icon metadata to vote and survey option tables
Author: cwatts
CreatedUtc: 2026-07-07
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.VotePostOptions', N'U') AS VotePostOptionsObjectId, OBJECT_ID(N'dbo.SurveyQuestionOptions', N'U') AS SurveyQuestionOptionsObjectId;
PostValidationQuery: SELECT COL_LENGTH(N'dbo.VotePostOptions', N'EmojiKind') AS VoteOptionEmojiKindColumn, COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiKind') AS SurveyOptionEmojiKindColumn;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration is additive and nullable. Existing vote and survey options remain unchanged, and
exports/reporting views are not reshaped. The bot stores either Unicode emoji text or a full custom
Discord emoji tag for Discord rendering, with optional name/id metadata for generated-card fallback.
Rollback is manual: remove the nullable emoji metadata columns and related check constraints after
rolling back any bot version that reads or writes them.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'dbo.VotePostOptions', N'EmojiKind') IS NULL
    ALTER TABLE [dbo].[VotePostOptions]
    ADD [EmojiKind] [varchar](20) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.VotePostOptions', N'EmojiText') IS NULL
    ALTER TABLE [dbo].[VotePostOptions]
    ADD [EmojiText] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.VotePostOptions', N'EmojiName') IS NULL
    ALTER TABLE [dbo].[VotePostOptions]
    ADD [EmojiName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.VotePostOptions', N'EmojiID') IS NULL
    ALTER TABLE [dbo].[VotePostOptions]
    ADD [EmojiID] [varchar](32) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.VotePostOptions', N'EmojiAnimated') IS NULL
    ALTER TABLE [dbo].[VotePostOptions]
    ADD [EmojiAnimated] [bit] NULL;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VotePostOptions_EmojiMetadata')
    ALTER TABLE [dbo].[VotePostOptions] DROP CONSTRAINT [CK_VotePostOptions_EmojiMetadata];
GO

ALTER TABLE [dbo].[VotePostOptions] WITH CHECK ADD CONSTRAINT [CK_VotePostOptions_EmojiMetadata]
CHECK (
    (
        [EmojiKind] IS NULL
        AND [EmojiText] IS NULL
        AND [EmojiName] IS NULL
        AND [EmojiID] IS NULL
        AND [EmojiAnimated] IS NULL
    )
    OR
    (
        [EmojiKind] = 'Unicode'
        AND [EmojiText] IS NOT NULL
        AND DATALENGTH([EmojiText]) = DATALENGTH(LTRIM(RTRIM([EmojiText])))
        AND LEN([EmojiText]) BETWEEN 1 AND 16
        AND [EmojiName] IS NULL
        AND [EmojiID] IS NULL
        AND ISNULL([EmojiAnimated], 0) = 0
    )
    OR
    (
        [EmojiKind] = 'CustomDiscord'
        AND [EmojiText] IS NOT NULL
        AND DATALENGTH([EmojiText]) = DATALENGTH(LTRIM(RTRIM([EmojiText])))
        AND LEN([EmojiText]) BETWEEN 1 AND 120
        AND [EmojiName] IS NOT NULL
        AND DATALENGTH([EmojiName]) = DATALENGTH(LTRIM(RTRIM([EmojiName])))
        AND LEN([EmojiName]) BETWEEN 2 AND 64
        AND [EmojiID] IS NOT NULL
        AND DATALENGTH([EmojiID]) = DATALENGTH(LTRIM(RTRIM([EmojiID])))
        AND LEN([EmojiID]) BETWEEN 2 AND 32
        AND [EmojiID] NOT LIKE '%[^0-9]%'
        AND [EmojiAnimated] IS NOT NULL
        AND [EmojiAnimated] IN (0, 1)
    )
);
GO

IF COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiKind') IS NULL
    ALTER TABLE [dbo].[SurveyQuestionOptions]
    ADD [EmojiKind] [varchar](20) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiText') IS NULL
    ALTER TABLE [dbo].[SurveyQuestionOptions]
    ADD [EmojiText] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiName') IS NULL
    ALTER TABLE [dbo].[SurveyQuestionOptions]
    ADD [EmojiName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiID') IS NULL
    ALTER TABLE [dbo].[SurveyQuestionOptions]
    ADD [EmojiID] [varchar](32) COLLATE Latin1_General_CI_AS NULL;
GO

IF COL_LENGTH(N'dbo.SurveyQuestionOptions', N'EmojiAnimated') IS NULL
    ALTER TABLE [dbo].[SurveyQuestionOptions]
    ADD [EmojiAnimated] [bit] NULL;
GO

IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestionOptions_EmojiMetadata')
    ALTER TABLE [dbo].[SurveyQuestionOptions] DROP CONSTRAINT [CK_SurveyQuestionOptions_EmojiMetadata];
GO

ALTER TABLE [dbo].[SurveyQuestionOptions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestionOptions_EmojiMetadata]
CHECK (
    (
        [EmojiKind] IS NULL
        AND [EmojiText] IS NULL
        AND [EmojiName] IS NULL
        AND [EmojiID] IS NULL
        AND [EmojiAnimated] IS NULL
    )
    OR
    (
        [EmojiKind] = 'Unicode'
        AND [EmojiText] IS NOT NULL
        AND DATALENGTH([EmojiText]) = DATALENGTH(LTRIM(RTRIM([EmojiText])))
        AND LEN([EmojiText]) BETWEEN 1 AND 16
        AND [EmojiName] IS NULL
        AND [EmojiID] IS NULL
        AND ISNULL([EmojiAnimated], 0) = 0
    )
    OR
    (
        [EmojiKind] = 'CustomDiscord'
        AND [EmojiText] IS NOT NULL
        AND DATALENGTH([EmojiText]) = DATALENGTH(LTRIM(RTRIM([EmojiText])))
        AND LEN([EmojiText]) BETWEEN 1 AND 120
        AND [EmojiName] IS NOT NULL
        AND DATALENGTH([EmojiName]) = DATALENGTH(LTRIM(RTRIM([EmojiName])))
        AND LEN([EmojiName]) BETWEEN 2 AND 64
        AND [EmojiID] IS NOT NULL
        AND DATALENGTH([EmojiID]) = DATALENGTH(LTRIM(RTRIM([EmojiID])))
        AND LEN([EmojiID]) BETWEEN 2 AND 32
        AND [EmojiID] NOT LIKE '%[^0-9]%'
        AND [EmojiAnimated] IS NOT NULL
        AND [EmojiAnimated] IN (0, 1)
    )
);
GO
