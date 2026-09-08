SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostReminders]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[VotePostReminders](
	[ReminderID] [bigint] IDENTITY(1,1) NOT NULL,
	[VotePostID] [bigint] NOT NULL,
	[OffsetMinutesBeforeClose] [int] NOT NULL,
	[DueAtUtc] [datetime2](0) NOT NULL,
	[ClaimedAtUtc] [datetime2](0) NULL,
	[SentAtUtc] [datetime2](0) NULL,
	[MessageID] [bigint] NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_VotePostReminders] PRIMARY KEY CLUSTERED 
(
	[ReminderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostReminders]') AND name = N'IX_VotePostReminders_Due')
CREATE NONCLUSTERED INDEX [IX_VotePostReminders_Due] ON [dbo].[VotePostReminders]
(
	[SentAtUtc] ASC,
	[DueAtUtc] ASC
)
INCLUDE([VotePostID],[ClaimedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_VotePostReminders_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[VotePostReminders] ADD  CONSTRAINT [DF_VotePostReminders_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostReminders_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostReminders]'))
ALTER TABLE [dbo].[VotePostReminders]  WITH CHECK ADD  CONSTRAINT [FK_VotePostReminders_VotePosts] FOREIGN KEY([VotePostID])
REFERENCES [dbo].[VotePosts] ([VotePostID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_VotePostReminders_VotePosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostReminders]'))
ALTER TABLE [dbo].[VotePostReminders] CHECK CONSTRAINT [FK_VotePostReminders_VotePosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostReminders_Offset]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostReminders]'))
ALTER TABLE [dbo].[VotePostReminders]  WITH CHECK ADD  CONSTRAINT [CK_VotePostReminders_Offset] CHECK  (([OffsetMinutesBeforeClose]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_VotePostReminders_Offset]') AND parent_object_id = OBJECT_ID(N'[dbo].[VotePostReminders]'))
ALTER TABLE [dbo].[VotePostReminders] CHECK CONSTRAINT [CK_VotePostReminders_Offset]
