SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SurveyReminders]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SurveyReminders](
	[ReminderID] [bigint] IDENTITY(1,1) NOT NULL,
	[SurveyID] [bigint] NOT NULL,
	[OffsetMinutesBeforeClose] [int] NOT NULL,
	[DueAtUtc] [datetime2](0) NOT NULL,
	[ClaimedAtUtc] [datetime2](0) NULL,
	[SentAtUtc] [datetime2](0) NULL,
	[MessageID] [bigint] NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SurveyReminders] PRIMARY KEY CLUSTERED 
(
	[ReminderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[SurveyReminders]') AND name = N'IX_SurveyReminders_Due')
CREATE NONCLUSTERED INDEX [IX_SurveyReminders_Due] ON [dbo].[SurveyReminders]
(
	[SentAtUtc] ASC,
	[DueAtUtc] ASC
)
INCLUDE([SurveyID],[ClaimedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SurveyReminders_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SurveyReminders] ADD  CONSTRAINT [DF_SurveyReminders_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyReminders_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyReminders]'))
ALTER TABLE [dbo].[SurveyReminders]  WITH CHECK ADD  CONSTRAINT [FK_SurveyReminders_SurveyPosts] FOREIGN KEY([SurveyID])
REFERENCES [dbo].[SurveyPosts] ([SurveyID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SurveyReminders_SurveyPosts]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyReminders]'))
ALTER TABLE [dbo].[SurveyReminders] CHECK CONSTRAINT [FK_SurveyReminders_SurveyPosts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyReminders_Offset]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyReminders]'))
ALTER TABLE [dbo].[SurveyReminders]  WITH CHECK ADD  CONSTRAINT [CK_SurveyReminders_Offset] CHECK  (([OffsetMinutesBeforeClose]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_SurveyReminders_Offset]') AND parent_object_id = OBJECT_ID(N'[dbo].[SurveyReminders]'))
ALTER TABLE [dbo].[SurveyReminders] CHECK CONSTRAINT [CK_SurveyReminders_Offset]
