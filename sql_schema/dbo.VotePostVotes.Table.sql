SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostVotes]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostVotes](
	[VotePostID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[OptionID] [bigint] NOT NULL,
	[GovernorID] [bigint] NULL,
	[OriginalOptionID] [bigint] NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_VotePostVotes] PRIMARY KEY CLUSTERED 
(
	[VotePostID] ASC,
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostVotes_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostVotes] ADD  CONSTRAINT [DF_VotePostVotes_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostVotes_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostVotes] ADD  CONSTRAINT [DF_VotePostVotes_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_Options]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes]  WITH CHECK ADD  CONSTRAINT [FK_VotePostVotes_Options] FOREIGN KEY([VotePostID], [OptionID])
REFERENCES [dbo].[VotePostOptions] ([VotePostID], [OptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_Options]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes] CHECK CONSTRAINT [FK_VotePostVotes_Options]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_OriginalOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes]  WITH CHECK ADD  CONSTRAINT [FK_VotePostVotes_OriginalOptions] FOREIGN KEY([VotePostID], [OriginalOptionID])
REFERENCES [dbo].[VotePostOptions] ([VotePostID], [OptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_OriginalOptions]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes] CHECK CONSTRAINT [FK_VotePostVotes_OriginalOptions]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes]  WITH CHECK ADD  CONSTRAINT [FK_VotePostVotes_VotePosts] FOREIGN KEY([VotePostID])
REFERENCES [dbo].[VotePosts] ([VotePostID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostVotes_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostVotes]'))
ALTER TABLE [dbo].[VotePostVotes] CHECK CONSTRAINT [FK_VotePostVotes_VotePosts]
