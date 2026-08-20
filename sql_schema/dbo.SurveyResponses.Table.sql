SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponses]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyResponses](
	[ResponseID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[OriginalAnswersJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyResponses] PRIMARY KEY CLUSTERED 
(
	[ResponseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponses]') AND name = N'UX_SurveyResponses_ResponseUser')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyResponses_ResponseUser] ON [dbo].[SurveyResponses]
(
	[ResponseID] ASC,
	[SurveyID] ASC,
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponses]') AND name = N'UX_SurveyResponses_User')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyResponses_User] ON [dbo].[SurveyResponses]
(
	[SurveyID] ASC,
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponses_OriginalAnswersJson]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponses] ADD  CONSTRAINT [DF_SurveyResponses_OriginalAnswersJson]  DEFAULT (N'{}') FOR [OriginalAnswersJson]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponses_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponses] ADD  CONSTRAINT [DF_SurveyResponses_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponses_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponses] ADD  CONSTRAINT [DF_SurveyResponses_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyResponses_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponses]'))
ALTER TABLE [dbo].[SurveyResponses]  WITH CHECK ADD  CONSTRAINT [FK_SurveyResponses_SurveyPosts] FOREIGN KEY([SurveyID])
REFERENCES [dbo].[SurveyPosts] ([SurveyID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyResponses_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponses]'))
ALTER TABLE [dbo].[SurveyResponses] CHECK CONSTRAINT [FK_SurveyResponses_SurveyPosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponses_OriginalAnswersJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponses]'))
ALTER TABLE [dbo].[SurveyResponses]  WITH CHECK ADD  CONSTRAINT [CK_SurveyResponses_OriginalAnswersJson] CHECK  ((isjson([OriginalAnswersJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponses_OriginalAnswersJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponses]'))
ALTER TABLE [dbo].[SurveyResponses] CHECK CONSTRAINT [CK_SurveyResponses_OriginalAnswersJson]
