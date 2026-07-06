SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyRatingAnswers](
	[SurveyRatingAnswerID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[ResponseID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[SurveyQuestionID] [bigint] NOT NULL,
	[QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[RatingValue] [tinyint] NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyRatingAnswers] PRIMARY KEY CLUSTERED 
(
	[SurveyRatingAnswerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]') AND name = N'IX_SurveyRatingAnswers_Response')
CREATE NONCLUSTERED INDEX [IX_SurveyRatingAnswers_Response] ON [dbo].[SurveyRatingAnswers]
(
	[ResponseID] ASC,
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]') AND name = N'IX_SurveyRatingAnswers_SurveyQuestion')
CREATE NONCLUSTERED INDEX [IX_SurveyRatingAnswers_SurveyQuestion] ON [dbo].[SurveyRatingAnswers]
(
	[SurveyID] ASC,
	[SurveyQuestionID] ASC
)
INCLUDE([ResponseID],[DiscordUserID],[RatingValue]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]') AND name = N'UX_SurveyRatingAnswers_ResponseQuestion')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRatingAnswers_ResponseQuestion] ON [dbo].[SurveyRatingAnswers]
(
	[ResponseID] ASC,
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingAnswers_QuestionType]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingAnswers] ADD  CONSTRAINT [DF_SurveyRatingAnswers_QuestionType]  DEFAULT ('Rating') FOR [QuestionType]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingAnswers_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingAnswers] ADD  CONSTRAINT [DF_SurveyRatingAnswers_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingAnswers_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingAnswers] ADD  CONSTRAINT [DF_SurveyRatingAnswers_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRatingAnswers_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers] CHECK CONSTRAINT [FK_SurveyRatingAnswers_Response]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRatingAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers] CHECK CONSTRAINT [FK_SurveyRatingAnswers_SurveyQuestions]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingAnswers_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRatingAnswers_QuestionType] CHECK  (([QuestionType]='Rating'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingAnswers_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers] CHECK CONSTRAINT [CK_SurveyRatingAnswers_QuestionType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingAnswers_Value]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRatingAnswers_Value] CHECK  (([RatingValue]>=(1) AND [RatingValue]<=(5)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingAnswers_Value]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingAnswers]'))
ALTER TABLE [dbo].[SurveyRatingAnswers] CHECK CONSTRAINT [CK_SurveyRatingAnswers_Value]
