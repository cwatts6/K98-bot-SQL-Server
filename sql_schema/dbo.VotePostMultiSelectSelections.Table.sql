SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostMultiSelectSelections](
	[VotePostID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[OptionID] [bigint] NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_VotePostMultiSelectSelections] PRIMARY KEY CLUSTERED 
(
	[VotePostID] ASC,
	[DiscordUserID] ASC,
	[OptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]') AND name = N'IX_VotePostMultiSelectSelections_PostOption')
CREATE NONCLUSTERED INDEX [IX_VotePostMultiSelectSelections_PostOption] ON [dbo].[VotePostMultiSelectSelections]
(
	[VotePostID] ASC,
	[OptionID] ASC
)
INCLUDE([DiscordUserID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostMultiSelectSelections_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostMultiSelectSelections] ADD  CONSTRAINT [DF_VotePostMultiSelectSelections_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectSelections_Options]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]'))
ALTER TABLE [dbo].[VotePostMultiSelectSelections]  WITH CHECK ADD  CONSTRAINT [FK_VotePostMultiSelectSelections_Options] FOREIGN KEY([VotePostID], [OptionID])
REFERENCES [dbo].[VotePostOptions] ([VotePostID], [OptionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectSelections_Options]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]'))
ALTER TABLE [dbo].[VotePostMultiSelectSelections] CHECK CONSTRAINT [FK_VotePostMultiSelectSelections_Options]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectSelections_Votes]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]'))
ALTER TABLE [dbo].[VotePostMultiSelectSelections]  WITH CHECK ADD  CONSTRAINT [FK_VotePostMultiSelectSelections_Votes] FOREIGN KEY([VotePostID], [DiscordUserID])
REFERENCES [dbo].[VotePostMultiSelectVotes] ([VotePostID], [DiscordUserID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostMultiSelectSelections_Votes]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]'))
ALTER TABLE [dbo].[VotePostMultiSelectSelections] CHECK CONSTRAINT [FK_VotePostMultiSelectSelections_Votes]
