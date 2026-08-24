SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostAudit](
	[AuditID] [bigint] IDENTITY(1,1) NOT NULL,
	[VotePostID] [bigint] NOT NULL,
	[ActorDiscordUserID] [bigint] NULL,
	[ActionType] [varchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[OptionID] [bigint] NULL,
	[PreviousOptionID] [bigint] NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_VotePostAudit] PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostAudit]') AND name = N'IX_VotePostAudit_VotePost')
CREATE NONCLUSTERED INDEX [IX_VotePostAudit_VotePost] ON [dbo].[VotePostAudit]
(
	[VotePostID] ASC,
	[CreatedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostAudit_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostAudit] ADD  CONSTRAINT [DF_VotePostAudit_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostAudit_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostAudit]'))
ALTER TABLE [dbo].[VotePostAudit]  WITH CHECK ADD  CONSTRAINT [FK_VotePostAudit_VotePosts] FOREIGN KEY([VotePostID])
REFERENCES [dbo].[VotePosts] ([VotePostID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostAudit_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostAudit]'))
ALTER TABLE [dbo].[VotePostAudit] CHECK CONSTRAINT [FK_VotePostAudit_VotePosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostAudit]'))
ALTER TABLE [dbo].[VotePostAudit]  WITH CHECK ADD  CONSTRAINT [CK_VotePostAudit_DetailsJson] CHECK  (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostAudit]'))
ALTER TABLE [dbo].[VotePostAudit] CHECK CONSTRAINT [CK_VotePostAudit_DetailsJson]
