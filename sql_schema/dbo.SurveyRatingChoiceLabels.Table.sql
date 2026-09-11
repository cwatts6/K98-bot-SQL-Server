SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyRatingChoiceLabels](
	[SurveyRatingChoiceLabelID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[SurveyQuestionID] [bigint] NOT NULL,
	[QuestionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[RatingValue] [tinyint] NOT NULL,
	[Label] [nvarchar](80) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyRatingChoiceLabels] PRIMARY KEY CLUSTERED 
(
	[SurveyRatingChoiceLabelID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]') AND name = N'UX_SurveyRatingChoiceLabels_QuestionValue')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyRatingChoiceLabels_QuestionValue] ON [dbo].[SurveyRatingChoiceLabels]
(
	[SurveyID] ASC,
	[SurveyQuestionID] ASC,
	[RatingValue] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingChoiceLabels_QuestionType]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD  CONSTRAINT [DF_SurveyRatingChoiceLabels_QuestionType]  DEFAULT ('Rating') FOR [QuestionType]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingChoiceLabels_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD  CONSTRAINT [DF_SurveyRatingChoiceLabels_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyRatingChoiceLabels_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] ADD  CONSTRAINT [DF_SurveyRatingChoiceLabels_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingChoiceLabels_Questions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels]  WITH CHECK ADD  CONSTRAINT [FK_SurveyRatingChoiceLabels_Questions] FOREIGN KEY([SurveyID], [SurveyQuestionID], [QuestionType])
REFERENCES [dbo].[SurveyQuestions] ([SurveyID], [SurveyQuestionID], [QuestionType])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyRatingChoiceLabels_Questions]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] CHECK CONSTRAINT [FK_SurveyRatingChoiceLabels_Questions]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_Label]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRatingChoiceLabels_Label] CHECK  ((len(ltrim(rtrim([Label])))>=(1) AND len(ltrim(rtrim([Label])))<=(80)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_Label]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] CHECK CONSTRAINT [CK_SurveyRatingChoiceLabels_Label]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRatingChoiceLabels_QuestionType] CHECK  (([QuestionType]='Rating'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_QuestionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] CHECK CONSTRAINT [CK_SurveyRatingChoiceLabels_QuestionType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_Value]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels]  WITH CHECK ADD  CONSTRAINT [CK_SurveyRatingChoiceLabels_Value] CHECK  (([RatingValue]>=(1) AND [RatingValue]<=(10)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyRatingChoiceLabels_Value]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyRatingChoiceLabels]'))
ALTER TABLE [dbo].[SurveyRatingChoiceLabels] CHECK CONSTRAINT [CK_SurveyRatingChoiceLabels_Value]
