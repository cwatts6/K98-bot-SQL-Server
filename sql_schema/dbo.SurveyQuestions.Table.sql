SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND type in (N'U'))
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
	[AllowDetails] [bit] NOT NULL,
 CONSTRAINT [PK_SurveyQuestions] PRIMARY KEY CLUSTERED 
(
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_Key')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_Key] ON [dbo].[SurveyQuestions]
(
	[SurveyID] ASC,
	[QuestionKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_Sort')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_Sort] ON [dbo].[SurveyQuestions]
(
	[SurveyID] ASC,
	[SortOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_SurveyQuestion')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_SurveyQuestion] ON [dbo].[SurveyQuestions]
(
	[SurveyID] ASC,
	[SurveyQuestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]') AND name = N'UX_SurveyQuestions_SurveyQuestionType')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyQuestions_SurveyQuestionType] ON [dbo].[SurveyQuestions]
(
	[SurveyID] ASC,
	[SurveyQuestionID] ASC,
	[QuestionType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyQuestions_IsRequired]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyQuestions] ADD  CONSTRAINT [DF_SurveyQuestions_IsRequired]  DEFAULT ((1)) FOR [IsRequired]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyQuestions_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyQuestions] ADD  CONSTRAINT [DF_SurveyQuestions_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyQuestions_AllowDetails]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyQuestions] ADD  CONSTRAINT [DF_SurveyQuestions_AllowDetails]  DEFAULT ((0)) FOR [AllowDetails]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyQuestions_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions]  WITH CHECK ADD  CONSTRAINT [FK_SurveyQuestions_SurveyPosts] FOREIGN KEY([SurveyID])
REFERENCES [dbo].[SurveyPosts] ([SurveyID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyQuestions_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions] CHECK CONSTRAINT [FK_SurveyQuestions_SurveyPosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Cardinality]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions]  WITH CHECK ADD  CONSTRAINT [CK_SurveyQuestions_Cardinality] CHECK  ((([QuestionType]='Rating' OR [QuestionType]='Text') AND [MinSelections]=(0) AND [MaxSelections]=(0) AND [AllowDetails]=(0) OR [QuestionType]='Ranking' AND [MinSelections]>=(2) AND [MaxSelections]=[MinSelections] AND [MaxSelections]<=(6) AND [AllowDetails]=(0) OR NOT ([QuestionType]='Ranking' OR [QuestionType]='Rating' OR [QuestionType]='Text') AND [MinSelections]>=(1) AND [MaxSelections]>=[MinSelections] AND [MaxSelections]<=(6) AND ([QuestionType]<>'SingleChoice' OR [MinSelections]=(1) AND [MaxSelections]=(1)) AND ([QuestionType]<>'MultiSelect' OR [MaxSelections]>=(2))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Cardinality]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions] CHECK CONSTRAINT [CK_SurveyQuestions_Cardinality]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Required]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions]  WITH CHECK ADD  CONSTRAINT [CK_SurveyQuestions_Required] CHECK  (([IsRequired]=(1) OR [IsRequired]=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Required]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions] CHECK CONSTRAINT [CK_SurveyQuestions_Required]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Type]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions]  WITH CHECK ADD  CONSTRAINT [CK_SurveyQuestions_Type] CHECK  (([QuestionType]='Ranking' OR [QuestionType]='Rating' OR [QuestionType]='Text' OR [QuestionType]='MultiSelect' OR [QuestionType]='SingleChoice'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyQuestions_Type]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyQuestions]'))
ALTER TABLE [dbo].[SurveyQuestions] CHECK CONSTRAINT [CK_SurveyQuestions_Type]
