SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyTextAnswers](
	[SurveyID] [bigint] NOT NULL,
	[ResponseID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[SurveyQuestionID] [bigint] NOT NULL,
	[AnswerText] [nvarchar](500) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyTextAnswers] PRIMARY KEY CLUSTERED 
(
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]') AND name = N'IX_SurveyTextAnswers_Response')
CREATE NONCLUSTERED INDEX [IX_SurveyTextAnswers_Response] ON [dbo].[SurveyTextAnswers]
(
	[ResponseID] ASC,
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyTextAnswers_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyTextAnswers] ADD  CONSTRAINT [DF_SurveyTextAnswers_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyTextAnswers_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyTextAnswers] ADD  CONSTRAINT [DF_SurveyTextAnswers_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyTextAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]'))
ALTER TABLE [dbo].[SurveyTextAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyTextAnswers_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyTextAnswers_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]'))
ALTER TABLE [dbo].[SurveyTextAnswers] CHECK CONSTRAINT [FK_SurveyTextAnswers_Response]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyTextAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]'))
ALTER TABLE [dbo].[SurveyTextAnswers]  WITH CHECK ADD  CONSTRAINT [FK_SurveyTextAnswers_SurveyQuestions] FOREIGN KEY([SurveyID], [SurveyQuestionID])
REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyTextAnswers_SurveyQuestions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyTextAnswers]'))
ALTER TABLE [dbo].[SurveyTextAnswers] CHECK CONSTRAINT [FK_SurveyTextAnswers_SurveyQuestions]
