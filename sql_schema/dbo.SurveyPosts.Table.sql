SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyPosts]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyPosts](
	[SurveyID] [bigint] IDENTITY(1,1) NOT NULL,
	[GuildID] [bigint] NOT NULL,
	[ChannelID] [bigint] NOT NULL,
	[MessageID] [bigint] NULL,
	[CreatedByDiscordUserID] [bigint] NOT NULL,
	[Title] [nvarchar](180) COLLATE Latin1_General_CI_AS NOT NULL,
	[Description] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
	[Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[AllowResponseChange] [bit] NOT NULL,
	[LaunchMentionEveryone] [bit] NOT NULL,
	[ReminderMentionEveryone] [bit] NOT NULL,
	[CloseMentionEveryone] [bit] NOT NULL,
	[OpensAtUtc] [datetime2](0) NULL,
	[ClosesAtUtc] [datetime2](0) NOT NULL,
	[ClosedAtUtc] [datetime2](0) NULL,
	[ClosedByDiscordUserID] [bigint] NULL,
	[ClosedReason] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[ResultVisibility] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyPosts] PRIMARY KEY CLUSTERED 
(
	[SurveyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyPosts]') AND name = N'IX_SurveyPosts_OpenDue')
CREATE NONCLUSTERED INDEX [IX_SurveyPosts_OpenDue] ON [dbo].[SurveyPosts]
(
	[Status] ASC,
	[ClosesAtUtc] ASC
)
INCLUDE([ChannelID],[MessageID],[CloseMentionEveryone]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_Status]  DEFAULT ('Open') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_AllowResponseChange]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_AllowResponseChange]  DEFAULT ((1)) FOR [AllowResponseChange]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_LaunchMentionEveryone]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_LaunchMentionEveryone]  DEFAULT ((0)) FOR [LaunchMentionEveryone]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_ReminderMentionEveryone]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_ReminderMentionEveryone]  DEFAULT ((0)) FOR [ReminderMentionEveryone]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_CloseMentionEveryone]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_CloseMentionEveryone]  DEFAULT ((0)) FOR [CloseMentionEveryone]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_ResultVisibility]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_ResultVisibility]  DEFAULT ('PublicLive') FOR [ResultVisibility]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyPosts_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyPosts] ADD  CONSTRAINT [DF_SurveyPosts_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_Closed]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyPosts_Closed] CHECK  (([Status]<>'Closed' OR [ClosedAtUtc] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_Closed]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts] CHECK CONSTRAINT [CK_SurveyPosts_Closed]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_ResultVisibility]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyPosts_ResultVisibility] CHECK  (([ResultVisibility]='HiddenUntilClose' OR [ResultVisibility]='PublicLive'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_ResultVisibility]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts] CHECK CONSTRAINT [CK_SurveyPosts_ResultVisibility]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts]  WITH CHECK ADD  CONSTRAINT [CK_SurveyPosts_Status] CHECK  (([Status]='Cancelled' OR [Status]='Closed' OR [Status]='Open'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyPosts_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyPosts]'))
ALTER TABLE [dbo].[SurveyPosts] CHECK CONSTRAINT [CK_SurveyPosts_Status]
