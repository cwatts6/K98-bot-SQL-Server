SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyResponseDrafts](
	[DraftID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[DraftPayloadJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[Revision] [int] NOT NULL,
	[Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
	[ExpiresAtUtc] [datetime2](0) NULL,
 CONSTRAINT [PK_SurveyResponseDrafts] PRIMARY KEY CLUSTERED 
(
	[DraftID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]') AND name = N'IX_SurveyResponseDrafts_Expiry')
CREATE NONCLUSTERED INDEX [IX_SurveyResponseDrafts_Expiry] ON [dbo].[SurveyResponseDrafts]
(
	[Status] ASC,
	[ExpiresAtUtc] ASC
)
INCLUDE([SurveyID],[DiscordUserID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]') AND name = N'IX_SurveyResponseDrafts_Updated')
CREATE NONCLUSTERED INDEX [IX_SurveyResponseDrafts_Updated] ON [dbo].[SurveyResponseDrafts]
(
	[Status] ASC,
	[UpdatedAtUtc] ASC
)
INCLUDE([SurveyID],[DiscordUserID],[ExpiresAtUtc],[Revision]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]') AND name = N'UX_SurveyResponseDrafts_User')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SurveyResponseDrafts_User] ON [dbo].[SurveyResponseDrafts]
(
	[SurveyID] ASC,
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponseDrafts_Revision]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponseDrafts] ADD  CONSTRAINT [DF_SurveyResponseDrafts_Revision]  DEFAULT ((1)) FOR [Revision]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponseDrafts_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponseDrafts] ADD  CONSTRAINT [DF_SurveyResponseDrafts_Status]  DEFAULT ('Active') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponseDrafts_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponseDrafts] ADD  CONSTRAINT [DF_SurveyResponseDrafts_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyResponseDrafts_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyResponseDrafts] ADD  CONSTRAINT [DF_SurveyResponseDrafts_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyResponseDrafts_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts]  WITH CHECK ADD  CONSTRAINT [FK_SurveyResponseDrafts_SurveyPosts] FOREIGN KEY([SurveyID])
REFERENCES [dbo].[SurveyPosts] ([SurveyID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyResponseDrafts_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts] CHECK CONSTRAINT [FK_SurveyResponseDrafts_SurveyPosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_ExpiredAt]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyResponseDrafts_ExpiredAt] CHECK  (([Status]<>'Expired' OR [ExpiresAtUtc] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_ExpiredAt]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts] CHECK CONSTRAINT [CK_SurveyResponseDrafts_ExpiredAt]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_PayloadJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyResponseDrafts_PayloadJson] CHECK  ((isjson([DraftPayloadJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_PayloadJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts] CHECK CONSTRAINT [CK_SurveyResponseDrafts_PayloadJson]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_Revision]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyResponseDrafts_Revision] CHECK  (([Revision]>=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_Revision]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts] CHECK CONSTRAINT [CK_SurveyResponseDrafts_Revision]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyResponseDrafts_Status] CHECK  (([Status]='Expired' OR [Status]='Active'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyResponseDrafts_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyResponseDrafts]'))
ALTER TABLE [dbo].[SurveyResponseDrafts] CHECK CONSTRAINT [CK_SurveyResponseDrafts_Status]
