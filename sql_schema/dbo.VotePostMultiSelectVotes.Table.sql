SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostMultiSelectVotes](
	[VotePostID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[OriginalOptionIDsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_VotePostMultiSelectVotes] PRIMARY KEY CLUSTERED 
(
	[VotePostID] ASC,
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]') AND name = N'IX_VotePostMultiSelectVotes_PostUpdated')
CREATE NONCLUSTERED INDEX [IX_VotePostMultiSelectVotes_PostUpdated] ON [dbo].[VotePostMultiSelectVotes]
(
	[VotePostID] ASC,
	[UpdatedAtUtc] ASC
)
INCLUDE([DiscordUserID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostMultiSelectVotes_OriginalOptionIDsJson]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD  CONSTRAINT [DF_VotePostMultiSelectVotes_OriginalOptionIDsJson]  DEFAULT (N'[]') FOR [OriginalOptionIDsJson]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostMultiSelectVotes_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD  CONSTRAINT [DF_VotePostMultiSelectVotes_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostMultiSelectVotes_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD  CONSTRAINT [DF_VotePostMultiSelectVotes_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectVotes_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]'))
ALTER TABLE [dbo].[VotePostMultiSelectVotes]  WITH CHECK ADD  CONSTRAINT [FK_VotePostMultiSelectVotes_VotePosts] FOREIGN KEY([VotePostID])
REFERENCES [dbo].[VotePosts] ([VotePostID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectVotes_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]'))
ALTER TABLE [dbo].[VotePostMultiSelectVotes] CHECK CONSTRAINT [FK_VotePostMultiSelectVotes_VotePosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostMultiSelectVotes_OriginalOptionIDsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]'))
ALTER TABLE [dbo].[VotePostMultiSelectVotes]  WITH CHECK ADD  CONSTRAINT [CK_VotePostMultiSelectVotes_OriginalOptionIDsJson] CHECK  ((isjson([OriginalOptionIDsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostMultiSelectVotes_OriginalOptionIDsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]'))
ALTER TABLE [dbo].[VotePostMultiSelectVotes] CHECK CONSTRAINT [CK_VotePostMultiSelectVotes_OriginalOptionIDsJson]
