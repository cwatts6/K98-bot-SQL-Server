SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyAudit](
	[AuditID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[ActorDiscordUserID] [bigint] NULL,
	[ActionType] [varchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyAudit] PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyAudit]') AND name = N'IX_SurveyAudit_Survey')
CREATE NONCLUSTERED INDEX [IX_SurveyAudit_Survey] ON [dbo].[SurveyAudit]
(
	[SurveyID] ASC,
	[CreatedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyAudit_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyAudit] ADD  CONSTRAINT [DF_SurveyAudit_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAudit_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAudit]'))
ALTER TABLE [dbo].[SurveyAudit]  WITH CHECK ADD  CONSTRAINT [FK_SurveyAudit_SurveyPosts] FOREIGN KEY([SurveyID])
REFERENCES [dbo].[SurveyPosts] ([SurveyID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyAudit_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAudit]'))
ALTER TABLE [dbo].[SurveyAudit] CHECK CONSTRAINT [FK_SurveyAudit_SurveyPosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAudit]'))
ALTER TABLE [dbo].[SurveyAudit]  WITH CHECK ADD  CONSTRAINT [CK_SurveyAudit_DetailsJson] CHECK  (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyAudit]'))
ALTER TABLE [dbo].[SurveyAudit] CHECK CONSTRAINT [CK_SurveyAudit_DetailsJson]
