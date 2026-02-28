SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkMatches](
	[MatchId] [bigint] IDENTITY(1,1) NOT NULL,
	[Alliance] [nchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[ArkWeekendDate] [date] NOT NULL,
	[MatchDay] [char](3) COLLATE Latin1_General_CI_AS NOT NULL,
	[MatchTimeUtc] [time](0) NOT NULL,
	[SignupCloseUtc] [datetime2](0) NOT NULL,
	[Status] [varchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[Notes] [nvarchar](2000) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
	[ConfirmationChannelId] [bigint] NULL,
	[ConfirmationMessageId] [bigint] NULL,
 CONSTRAINT [PK_ArkMatches] PRIMARY KEY CLUSTERED 
(
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]') AND name = N'IX_ArkMatches_Open')
CREATE NONCLUSTERED INDEX [IX_ArkMatches_Open] ON [dbo].[ArkMatches]
(
	[Status] ASC,
	[ArkWeekendDate] ASC
)
INCLUDE([Alliance],[MatchDay],[MatchTimeUtc],[SignupCloseUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]') AND name = N'UX_ArkMatches_Alliance_Weekend')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ArkMatches_Alliance_Weekend] ON [dbo].[ArkMatches]
(
	[Alliance] ASC,
	[ArkWeekendDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatches_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatches] ADD  CONSTRAINT [DF_ArkMatches_Status]  DEFAULT ('Scheduled') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatches_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatches] ADD  CONSTRAINT [DF_ArkMatches_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatches_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatches] ADD  CONSTRAINT [DF_ArkMatches_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkMatches_Alliance]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches]  WITH CHECK ADD  CONSTRAINT [FK_ArkMatches_Alliance] FOREIGN KEY([Alliance])
REFERENCES [dbo].[ArkAlliances] ([Alliance])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkMatches_Alliance]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches] CHECK CONSTRAINT [FK_ArkMatches_Alliance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatches_MatchDay]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches]  WITH CHECK ADD  CONSTRAINT [CK_ArkMatches_MatchDay] CHECK  (([MatchDay]='Sun' OR [MatchDay]='Sat'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatches_MatchDay]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches] CHECK CONSTRAINT [CK_ArkMatches_MatchDay]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatches_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches]  WITH CHECK ADD  CONSTRAINT [CK_ArkMatches_Status] CHECK  (([Status]='Completed' OR [Status]='Cancelled' OR [Status]='Locked' OR [Status]='Scheduled'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatches_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]'))
ALTER TABLE [dbo].[ArkMatches] CHECK CONSTRAINT [CK_ArkMatches_Status]
