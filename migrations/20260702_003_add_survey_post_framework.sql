/*
MigrationId: 20260702_003_add_survey_post_framework
Purpose: Add SQL-backed choice-only multi-question survey post framework tables
Author: cwatts
CreatedUtc: 2026-07-02
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyPosts', N'U') AS SurveyPostsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.SurveyPosts', N'U') AS SurveyPostsObjectId, OBJECT_ID(N'dbo.SurveyResponses', N'U') AS SurveyResponsesObjectId, OBJECT_ID(N'dbo.SurveyAnswers', N'U') AS SurveyAnswersObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
Survey storage is additive and separate from dbo.VotePosts so existing one-choice and
single-question multi-select vote behavior remains untouched. This first survey slice stores
required choice-only questions and selected options. Free-text answers and optional extra-detail
fields are intentionally deferred to the next phase and should be added with additive columns or
dedicated answer-detail tables after the product/UX approval for that slice.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyPosts]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyPosts](
        [SurveyID] [bigint] IDENTITY(1,1) NOT NULL,
        [GuildID] [bigint] NOT NULL,
        [ChannelID] [bigint] NOT NULL,
        [MessageID] [bigint] NULL,
        [CreatedByDiscordUserID] [bigint] NOT NULL,
        [Title] [nvarchar](180) COLLATE Latin1_General_CI_AS NOT NULL,
        [Description] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
        [Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [AllowResponseChange] [bit] NOT NULL,
        [LaunchMentionEveryone] [bit] NOT NULL,
        [ReminderMentionEveryone] [bit] NOT NULL,
        [CloseMentionEveryone] [bit] NOT NULL,
        [OpensAtUtc] [datetime2](0) NULL,
        [ClosesAtUtc] [datetime2](0) NOT NULL,
        [ClosedAtUtc] [datetime2](0) NULL,
        [ClosedByDiscordUserID] [bigint] NULL,
        [ClosedReason] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
        [ResultVisibility] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyPosts] PRIMARY KEY CLUSTERED ([SurveyID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyQuestions](
        [SurveyQuestionID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [QuestionKey] [varchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
        [Prompt] [nvarchar](180) COLLATE Latin1_General_CI_AS NOT NULL,
        [QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
        [SortOrder] [int] NOT NULL,
        [IsRequired] [bit] NOT NULL,
        [MinSelections] [tinyint] NOT NULL,
        [MaxSelections] [tinyint] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyQuestions] PRIMARY KEY CLUSTERED ([SurveyQuestionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestionOptions]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyQuestionOptions](
        [SurveyOptionID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [OptionKey] [varchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
        [Label] [nvarchar](80) COLLATE Latin1_General_CI_AS NOT NULL,
        [SortOrder] [int] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyQuestionOptions] PRIMARY KEY CLUSTERED ([SurveyOptionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponses]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyResponses](
        [ResponseID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [OriginalAnswersJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyResponses] PRIMARY KEY CLUSTERED ([ResponseID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyAnswers](
        [SurveyID] [bigint] NOT NULL,
        [ResponseID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [SurveyQuestionID] [bigint] NOT NULL,
        [SurveyOptionID] [bigint] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyAnswers] PRIMARY KEY CLUSTERED ([SurveyID] ASC, [DiscordUserID] ASC, [SurveyQuestionID] ASC, [SurveyOptionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyReminders]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyReminders](
        [ReminderID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [OffsetMinutesBeforeClose] [int] NOT NULL,
        [DueAtUtc] [datetime2](0) NOT NULL,
        [ClaimedAtUtc] [datetime2](0) NULL,
        [SentAtUtc] [datetime2](0) NULL,
        [MessageID] [bigint] NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyReminders] PRIMARY KEY CLUSTERED ([ReminderID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAudit]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[SurveyAudit](
        [AuditID] [bigint] IDENTITY(1,1) NOT NULL,
        [SurveyID] [bigint] NOT NULL,
        [ActorDiscordUserID] [bigint] NULL,
        [ActionType] [varchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
        [DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_SurveyAudit] PRIMARY KEY CLUSTERED ([AuditID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_Status')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_Status] DEFAULT ('Open') FOR [Status];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_AllowResponseChange')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_AllowResponseChange] DEFAULT ((1)) FOR [AllowResponseChange];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_LaunchMentionEveryone')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_LaunchMentionEveryone] DEFAULT ((0)) FOR [LaunchMentionEveryone];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_ReminderMentionEveryone')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_ReminderMentionEveryone] DEFAULT ((0)) FOR [ReminderMentionEveryone];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_CloseMentionEveryone')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_CloseMentionEveryone] DEFAULT ((0)) FOR [CloseMentionEveryone];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_ResultVisibility')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_ResultVisibility] DEFAULT ('PublicLive') FOR [ResultVisibility];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyPosts_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyPosts] ADD CONSTRAINT [DF_SurveyPosts_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyQuestions_IsRequired')
    ALTER TABLE [dbo].[SurveyQuestions] ADD CONSTRAINT [DF_SurveyQuestions_IsRequired] DEFAULT ((1)) FOR [IsRequired];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyQuestions_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyQuestions] ADD CONSTRAINT [DF_SurveyQuestions_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyQuestionOptions_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyQuestionOptions] ADD CONSTRAINT [DF_SurveyQuestionOptions_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponses_OriginalAnswersJson')
    ALTER TABLE [dbo].[SurveyResponses] ADD CONSTRAINT [DF_SurveyResponses_OriginalAnswersJson] DEFAULT (N'{}') FOR [OriginalAnswersJson];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponses_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyResponses] ADD CONSTRAINT [DF_SurveyResponses_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyResponses_UpdatedAtUtc')
    ALTER TABLE [dbo].[SurveyResponses] ADD CONSTRAINT [DF_SurveyResponses_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyAnswers_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyAnswers] ADD CONSTRAINT [DF_SurveyAnswers_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyReminders_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyReminders] ADD CONSTRAINT [DF_SurveyReminders_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_SurveyAudit_CreatedAtUtc')
    ALTER TABLE [dbo].[SurveyAudit] ADD CONSTRAINT [DF_SurveyAudit_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponses]') AND name = N'UX_SurveyResponses_User')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyResponses_User] ON [dbo].[SurveyResponses]([SurveyID], [DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_SurveyQuestion')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_SurveyQuestion] ON [dbo].[SurveyQuestions]([SurveyID], [SurveyQuestionID]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestionOptions]') AND name = N'UX_SurveyQuestionOptions_QuestionOption')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestionOptions_QuestionOption] ON [dbo].[SurveyQuestionOptions]([SurveyQuestionID], [SurveyOptionID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyQuestions_SurveyPosts')
    ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [FK_SurveyQuestions_SurveyPosts] FOREIGN KEY([SurveyID]) REFERENCES [dbo].[SurveyPosts] ([SurveyID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyQuestionOptions_Questions')
    ALTER TABLE [dbo].[SurveyQuestionOptions] WITH CHECK ADD CONSTRAINT [FK_SurveyQuestionOptions_Questions] FOREIGN KEY([SurveyQuestionID]) REFERENCES [dbo].[SurveyQuestions] ([SurveyQuestionID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyResponses_SurveyPosts')
    ALTER TABLE [dbo].[SurveyResponses] WITH CHECK ADD CONSTRAINT [FK_SurveyResponses_SurveyPosts] FOREIGN KEY([SurveyID]) REFERENCES [dbo].[SurveyPosts] ([SurveyID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswers_Responses')
    ALTER TABLE [dbo].[SurveyAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswers_Responses] FOREIGN KEY([ResponseID]) REFERENCES [dbo].[SurveyResponses] ([ResponseID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswers_ResponseUser')
    ALTER TABLE [dbo].[SurveyAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswers_ResponseUser] FOREIGN KEY([SurveyID], [DiscordUserID]) REFERENCES [dbo].[SurveyResponses] ([SurveyID], [DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswers_SurveyQuestions')
    ALTER TABLE [dbo].[SurveyAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID]) REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAnswers_QuestionOptions')
    ALTER TABLE [dbo].[SurveyAnswers] WITH CHECK ADD CONSTRAINT [FK_SurveyAnswers_QuestionOptions] FOREIGN KEY([SurveyQuestionID], [SurveyOptionID]) REFERENCES [dbo].[SurveyQuestionOptions] ([SurveyQuestionID], [SurveyOptionID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyReminders_SurveyPosts')
    ALTER TABLE [dbo].[SurveyReminders] WITH CHECK ADD CONSTRAINT [FK_SurveyReminders_SurveyPosts] FOREIGN KEY([SurveyID]) REFERENCES [dbo].[SurveyPosts] ([SurveyID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_SurveyAudit_SurveyPosts')
    ALTER TABLE [dbo].[SurveyAudit] WITH CHECK ADD CONSTRAINT [FK_SurveyAudit_SurveyPosts] FOREIGN KEY([SurveyID]) REFERENCES [dbo].[SurveyPosts] ([SurveyID]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_Key')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_Key] ON [dbo].[SurveyQuestions]([SurveyID], [QuestionKey]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_Sort')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_Sort] ON [dbo].[SurveyQuestions]([SurveyID], [SortOrder]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestionOptions]') AND name = N'UX_SurveyQuestionOptions_Key')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestionOptions_Key] ON [dbo].[SurveyQuestionOptions]([SurveyQuestionID], [OptionKey]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestionOptions]') AND name = N'UX_SurveyQuestionOptions_Sort')
    CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestionOptions_Sort] ON [dbo].[SurveyQuestionOptions]([SurveyQuestionID], [SortOrder]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyPosts]') AND name = N'IX_SurveyPosts_OpenDue')
    CREATE NONCLUSTERED INDEX [IX_SurveyPosts_OpenDue] ON [dbo].[SurveyPosts]([Status], [ClosesAtUtc]) INCLUDE([ChannelID], [MessageID], [CloseMentionEveryone]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyReminders]') AND name = N'IX_SurveyReminders_Due')
    CREATE NONCLUSTERED INDEX [IX_SurveyReminders_Due] ON [dbo].[SurveyReminders]([SentAtUtc], [DueAtUtc]) INCLUDE([SurveyID], [ClaimedAtUtc]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAudit]') AND name = N'IX_SurveyAudit_Survey')
    CREATE NONCLUSTERED INDEX [IX_SurveyAudit_Survey] ON [dbo].[SurveyAudit]([SurveyID], [CreatedAtUtc]);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyPosts_Status')
    ALTER TABLE [dbo].[SurveyPosts] WITH CHECK ADD CONSTRAINT [CK_SurveyPosts_Status] CHECK ([Status] IN ('Open', 'Closed', 'Cancelled'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyPosts_Closed')
    ALTER TABLE [dbo].[SurveyPosts] WITH CHECK ADD CONSTRAINT [CK_SurveyPosts_Closed] CHECK (([Status] <> 'Closed') OR ([ClosedAtUtc] IS NOT NULL));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyPosts_ResultVisibility')
    ALTER TABLE [dbo].[SurveyPosts] WITH CHECK ADD CONSTRAINT [CK_SurveyPosts_ResultVisibility] CHECK ([ResultVisibility] IN ('PublicLive', 'HiddenUntilClose'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Type')
    ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Type] CHECK ([QuestionType] IN ('SingleChoice', 'MultiSelect'));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Required')
    ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Required] CHECK ([IsRequired] = 1);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyQuestions_Cardinality')
    ALTER TABLE [dbo].[SurveyQuestions] WITH CHECK ADD CONSTRAINT [CK_SurveyQuestions_Cardinality] CHECK ([MinSelections] >= 1 AND [MaxSelections] >= [MinSelections] AND [MaxSelections] <= 6 AND ([QuestionType] <> 'SingleChoice' OR ([MinSelections] = 1 AND [MaxSelections] = 1)) AND ([QuestionType] <> 'MultiSelect' OR [MaxSelections] >= 2));
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyResponses_OriginalAnswersJson')
    ALTER TABLE [dbo].[SurveyResponses] WITH CHECK ADD CONSTRAINT [CK_SurveyResponses_OriginalAnswersJson] CHECK (ISJSON([OriginalAnswersJson]) = 1);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyReminders_Offset')
    ALTER TABLE [dbo].[SurveyReminders] WITH CHECK ADD CONSTRAINT [CK_SurveyReminders_Offset] CHECK ([OffsetMinutesBeforeClose] > 0);
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_SurveyAudit_DetailsJson')
    ALTER TABLE [dbo].[SurveyAudit] WITH CHECK ADD CONSTRAINT [CK_SurveyAudit_DetailsJson] CHECK ([DetailsJson] IS NULL OR ISJSON([DetailsJson]) = 1);
GO



