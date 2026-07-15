SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyAnswers](
	[SurveyID] [bigint] NOT NULL,
	[ResponseID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[SurveyQuestionID] [bigint] NOT NULL,
	[SurveyOptionID] [bigint] NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyAnswers] PRIMARY KEY CLUSTERED 
(
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC,
	[SurveyOptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]') AND name = N'UX_SurveyAnswers_ResponseOption')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyAnswers_ResponseOption] ON [dbo].[SurveyAnswers]
(
	[ResponseID] ASC,
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC,
	[SurveyOptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyAnswers_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyAnswers] ADD  CONSTRAINT [DF_SurveyAnswers_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_QuestionOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAnswers_QuestionOptions] FOREIGN KEY([SurveyQuestionID], [SurveyOptionID])
REFERENCES [dbo].[SurveyQuestionOptions] ([SurveyQuestionID], [SurveyOptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_QuestionOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers] CHECK CONSTRAINT [FK_SurveyAnswers_QuestionOptions]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAnswers_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers] CHECK CONSTRAINT [FK_SurveyAnswers_Response]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID])
REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswers]'))
ALTER TABLE [dbo].[SurveyAnswers] CHECK CONSTRAINT [FK_SurveyAnswers_SurveyQuestions]
