SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostOptions]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostOptions](
	[OptionID] [bigint] IDENTITY(1,1) NOT NULL,
	[VotePostID] [bigint] NOT NULL,
	[OptionKey] [varchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[Label] [nvarchar](80) COLLATE Latin1_General_CI_AS NOT NULL,
	[SortOrder] [int] NOT NULL,
	[ButtonStyle] [varchar](16) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[EmojiKind] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[EmojiText] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL,
	[EmojiName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[EmojiID] [varchar](32) COLLATE Latin1_General_CI_AS NULL,
	[EmojiAnimated] [bit] NULL,
 CONSTRAINT [PK_VotePostOptions] PRIMARY KEY CLUSTERED 
(
	[OptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostOptions]') AND name = N'UX_VotePostOptions_Key')
CREATE UNIQUE NONCLUSTERED INDEX [UX_VotePostOptions_Key] ON [dbo].[VotePostOptions]
(
	[VotePostID] ASC,
	[OptionKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostOptions]') AND name = N'UX_VotePostOptions_PostOption')
CREATE UNIQUE NONCLUSTERED INDEX [UX_VotePostOptions_PostOption] ON [dbo].[VotePostOptions]
(
	[VotePostID] ASC,
	[OptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostOptions]') AND name = N'UX_VotePostOptions_Sort')
CREATE UNIQUE NONCLUSTERED INDEX [UX_VotePostOptions_Sort] ON [dbo].[VotePostOptions]
(
	[VotePostID] ASC,
	[SortOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostOptions_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostOptions] ADD  CONSTRAINT [DF_VotePostOptions_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostOptions_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostOptions]'))
ALTER TABLE [dbo].[VotePostOptions]  WITH CHECK ADD  CONSTRAINT [FK_VotePostOptions_VotePosts] FOREIGN KEY([VotePostID])
REFERENCES [dbo].[VotePosts] ([VotePostID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostOptions_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostOptions]'))
ALTER TABLE [dbo].[VotePostOptions] CHECK CONSTRAINT [FK_VotePostOptions_VotePosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostOptions_EmojiMetadata]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostOptions]'))
ALTER TABLE [dbo].[VotePostOptions]  WITH CHECK ADD  CONSTRAINT [CK_VotePostOptions_EmojiMetadata] CHECK  (([EmojiKind] IS NULL AND [EmojiText] IS NULL AND [EmojiName] IS NULL AND [EmojiID] IS NULL AND [EmojiAnimated] IS NULL OR [EmojiKind]='Unicode' AND [EmojiText] IS NOT NULL AND datalength([EmojiText])=datalength(ltrim(rtrim([EmojiText]))) AND (len([EmojiText])>=(1) AND len([EmojiText])<=(16)) AND [EmojiName] IS NULL AND [EmojiID] IS NULL AND isnull([EmojiAnimated],(0))=(0) OR [EmojiKind]='CustomDiscord' AND [EmojiText] IS NOT NULL AND datalength([EmojiText])=datalength(ltrim(rtrim([EmojiText]))) AND (len([EmojiText])>=(1) AND len([EmojiText])<=(120)) AND [EmojiName] IS NOT NULL AND datalength([EmojiName])=datalength(ltrim(rtrim([EmojiName]))) AND (len([EmojiName])>=(2) AND len([EmojiName])<=(64)) AND [EmojiID] IS NOT NULL AND datalength([EmojiID])=datalength(ltrim(rtrim([EmojiID]))) AND (len([EmojiID])>=(2) AND len([EmojiID])<=(32)) AND NOT [EmojiID] like '%[^0-9]%' AND [EmojiAnimated] IS NOT NULL AND ([EmojiAnimated]=(1) OR [EmojiAnimated]=(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostOptions_EmojiMetadata]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostOptions]'))
ALTER TABLE [dbo].[VotePostOptions] CHECK CONSTRAINT [CK_VotePostOptions_EmojiMetadata]
