SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceAdminReview](
	[ReviewID] [uniqueidentifier] NOT NULL,
	[ReviewSequence] [bigint] IDENTITY(1,1) NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ReviewKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActorID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[GuildID] [nvarchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChannelID] [nvarchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Version] [bigint] NOT NULL,
	[ReviewState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PayloadJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[PayloadHash] [binary](32) NOT NULL,
	[OutcomeJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[ExpiresUTC] [datetime2](0) NOT NULL,
	[CompletedUTC] [datetime2](0) NULL,
 CONSTRAINT [PK_SourceAdminReview] PRIMARY KEY CLUSTERED 
(
	[ReviewID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]') AND name = N'IX_SourceAdminReview_Owner')
CREATE NONCLUSTERED INDEX [IX_SourceAdminReview_Owner] ON [KVK].[SourceAdminReview]
(
	[ActorID] ASC,
	[GuildID] ASC,
	[ChannelID] ASC,
	[ReviewState] ASC,
	[CreatedUTC] ASC
)
INCLUDE([KVK_NO],[ReviewKind]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_Kind] CHECK  ((([ReviewKind]='configuration' OR [ReviewKind]='match_update' OR [ReviewKind]='intake' OR [ReviewKind]='choose_source') AND datalength([ReviewKind])=len([ReviewKind])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Outcome]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_Outcome] CHECK  (([OutcomeJson] IS NULL OR isjson([OutcomeJson])=(1) AND datalength([OutcomeJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Outcome]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_Outcome]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Payload]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_Payload] CHECK  ((isjson([PayloadJson])=(1) AND datalength([PayloadJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Payload]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_Payload]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_Scope] CHECK  (([KVK_NO]>(0) AND [Version]>(0) AND len([ActorID])>(0) AND len([GuildID])>(0) AND len([ChannelID])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_State] CHECK  ((datalength([ReviewState])=len([ReviewState]) AND ([ReviewState]='pending' AND [OutcomeJson] IS NULL AND [CompletedUTC] IS NULL OR ([ReviewState]='cancelled' OR [ReviewState]='completed') AND [OutcomeJson] IS NOT NULL AND [CompletedUTC] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview]  WITH CHECK ADD  CONSTRAINT [CK_SourceAdminReview_Time] CHECK  (([ExpiresUTC]>[CreatedUTC] AND ([CompletedUTC] IS NULL OR [CompletedUTC]>=[CreatedUTC])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAdminReview_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAdminReview]'))
ALTER TABLE [KVK].[SourceAdminReview] CHECK CONSTRAINT [CK_SourceAdminReview_Time]
