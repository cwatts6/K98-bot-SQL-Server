SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND type in (N'U'))
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
 CONSTRAINT [PK_SurveyRankingAnswers] PRIMARY KEY CLUSTERED 
(
	[SurveyRankingAnswerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND name = N'IX_SurveyRankingAnswers_Response')
CREATE NONCLUSTERED INDEX [IX_SurveyRankingAnswers_Response] ON [dbo].[SurveyRankingAnswers]
(
	[ResponseID] ASC,
	[SurveyQuestionID] ASC,
	[RankValue] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND name = N'IX_SurveyRankingAnswers_SurveyQuestion')
CREATE NONCLUSTERED INDEX [IX_SurveyRankingAnswers_SurveyQuestion] ON [dbo].[SurveyRankingAnswers]
(
	[SurveyID] ASC,
	[SurveyQuestionID] ASC
)
INCLUDE([ResponseID],[DiscordUserID],[SurveyOptionID],[RankValue]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND name = N'UX_SurveyRankingAnswers_ResponseQuestionOption')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRankingAnswers_ResponseQuestionOption] ON [dbo].[SurveyRankingAnswers]
(
	[ResponseID] ASC,
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC,
	[SurveyOptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]') AND name = N'UX_SurveyRankingAnswers_ResponseQuestionRank')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRankingAnswers_ResponseQuestionRank] ON [dbo].[SurveyRankingAnswers]
(
	[ResponseID] ASC,
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC,
	[RankValue] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRankingAnswers_QuestionType]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRankingAnswers] ADD  CONSTRAINT [DF_SurveyRankingAnswers_QuestionType]  DEFAULT ('Ranking') FOR [QuestionType]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRankingAnswers_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRankingAnswers] ADD  CONSTRAINT [DF_SurveyRankingAnswers_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRankingAnswers_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRankingAnswers] ADD  CONSTRAINT [DF_SurveyRankingAnswers_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_QuestionOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRankingAnswers_QuestionOptions] FOREIGN KEY([SurveyQuestionID], [SurveyOptionID])
REFERENCES [dbo].[SurveyQuestionOptions] ([SurveyQuestionID], [SurveyOptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_QuestionOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers] CHECK CONSTRAINT [FK_SurveyRankingAnswers_QuestionOptions]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRankingAnswers_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers] CHECK CONSTRAINT [FK_SurveyRankingAnswers_Response]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRankingAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRankingAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers] CHECK CONSTRAINT [FK_SurveyRankingAnswers_SurveyQuestions]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRankingAnswers_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRankingAnswers_QuestionType] CHECK  (([QuestionType]='Ranking'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRankingAnswers_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers] CHECK CONSTRAINT [CK_SurveyRankingAnswers_QuestionType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRankingAnswers_RankValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRankingAnswers_RankValue] CHECK  (([RankValue]>=(1) AND [RankValue]<=(6)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRankingAnswers_RankValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRankingAnswers]'))
ALTER TABLE [dbo].[SurveyRankingAnswers] CHECK CONSTRAINT [CK_SurveyRankingAnswers_RankValue]
