SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Events]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_Events](
	[EventId] [bigint] IDENTITY(1,1) NOT NULL,
	[VariantId] [int] NOT NULL,
	[EventName] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
	[StartUtc] [datetime2](7) NOT NULL,
	[EndUtc] [datetime2](7) NOT NULL,
	[SignupCloseUtc] [datetime2](7) NOT NULL,
	[EventMode] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[RuleMode] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[RulesText] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[PublishVersion] [int] NOT NULL,
	[LastPublishedUtc] [datetime2](7) NULL,
	[SignupEmbedMessageId] [bigint] NULL,
	[SignupEmbedChannelId] [bigint] NULL,
	[CalendarEventSourceId] [bigint] NULL,
	[CreatedByDiscordId] [bigint] NULL,
	[CompletedAtUtc] [datetime2](7) NULL,
	[CompletedByDiscordId] [bigint] NULL,
	[ReopenedAtUtc] [datetime2](7) NULL,
	[ReopenedByDiscordId] [bigint] NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
	[AwardEmbedMessageId] [bigint] NULL,
	[AwardEmbedChannelId] [bigint] NULL,
 CONSTRAINT [PK_MGE_Events] PRIMARY KEY CLUSTERED 
(
	[EventId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Events]') AND name = N'IX_MGE_Events_StartUtc')
CREATE NONCLUSTERED INDEX [IX_MGE_Events_StartUtc] ON [dbo].[MGE_Events]
(
	[StartUtc] ASC
)
INCLUDE([VariantId],[Status],[EventMode]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Events]') AND name = N'IX_MGE_Events_Status')
CREATE NONCLUSTERED INDEX [IX_MGE_Events_Status] ON [dbo].[MGE_Events]
(
	[Status] ASC,
	[StartUtc] ASC
)
INCLUDE([VariantId],[EventMode],[SignupCloseUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Events]') AND name = N'UX_MGE_Events_CalendarSource')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_Events_CalendarSource] ON [dbo].[MGE_Events]
(
	[CalendarEventSourceId] ASC
)
WHERE ([CalendarEventSourceId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_EventMode]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_EventMode]  DEFAULT ('controlled') FOR [EventMode]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_Status]  DEFAULT ('signup_open') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_RuleMode]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_RuleMode]  DEFAULT ('fixed') FOR [RuleMode]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_PublishVersion]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_PublishVersion]  DEFAULT ((0)) FOR [PublishVersion]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Events_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Events] ADD  CONSTRAINT [DF_MGE_Events_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Events_VariantId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Events_VariantId] FOREIGN KEY([VariantId])
REFERENCES [dbo].[MGE_Variants] ([VariantId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Events_VariantId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events] CHECK CONSTRAINT [FK_MGE_Events_VariantId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_EventMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Events_EventMode] CHECK  (([EventMode]='open' OR [EventMode]='controlled'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_EventMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events] CHECK CONSTRAINT [CK_MGE_Events_EventMode]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_RuleMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Events_RuleMode] CHECK  (([RuleMode]='open' OR [RuleMode]='fixed'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_RuleMode]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events] CHECK CONSTRAINT [CK_MGE_Events_RuleMode]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_RulesText]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Events_RulesText] CHECK  ((len([RulesText])<=(4000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_RulesText]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events] CHECK CONSTRAINT [CK_MGE_Events_RulesText]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Events_Status] CHECK  (([Status]='reopened' OR [Status]='completed' OR [Status]='published' OR [Status]='signup_closed' OR [Status]='signup_open' OR [Status]='created'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Events_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Events]'))
ALTER TABLE [dbo].[MGE_Events] CHECK CONSTRAINT [CK_MGE_Events_Status]
