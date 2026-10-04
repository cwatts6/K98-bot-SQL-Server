SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyAnswerDetails](
	[SurveyID] [bigint] NOT NULL,
	[ResponseID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[SurveyQuestionID] [bigint] NOT NULL,
	[SurveyOptionID] [bigint] NOT NULL,
	[DetailText] [nvarchar](300) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyAnswerDetails] PRIMARY KEY CLUSTERED 
(
	[SurveyID] ASC,
	[DiscordUserID] ASC,
	[SurveyQuestionID] ASC,
	[SurveyOptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]') AND name = N'IX_SurveyAnswerDetails_Response')
CREATE NONCLUSTERED INDEX [IX_SurveyAnswerDetails_Response] ON [dbo].[SurveyAnswerDetails]
(
	[ResponseID] ASC,
	[SurveyQuestionID] ASC,
	[SurveyOptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyAnswerDetails_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyAnswerDetails] ADD  CONSTRAINT [DF_SurveyAnswerDetails_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyAnswerDetails_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyAnswerDetails] ADD  CONSTRAINT [DF_SurveyAnswerDetails_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswerDetails_Answers]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]'))
ALTER TABLE [dbo].[SurveyAnswerDetails]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAnswerDetails_Answers] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID])
REFERENCES [dbo].[SurveyAnswers] ([ResponseID], [SurveyID], [DiscordUserID], [SurveyQuestionID], [SurveyOptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswerDetails_Answers]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]'))
ALTER TABLE [dbo].[SurveyAnswerDetails] CHECK CONSTRAINT [FK_SurveyAnswerDetails_Answers]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswerDetails_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]'))
ALTER TABLE [dbo].[SurveyAnswerDetails]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAnswerDetails_Response] FOREIGN KEY([ResponseID], [SurveyID], [DiscordUserID])
REFERENCES [dbo].[SurveyResponses] ([ResponseID], [SurveyID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAnswerDetails_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAnswerDetails]'))
ALTER TABLE [dbo].[SurveyAnswerDetails] CHECK CONSTRAINT [FK_SurveyAnswerDetails_Response]
