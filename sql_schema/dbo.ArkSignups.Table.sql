SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkSignups](
	[SignupId] [bigint] IDENTITY(1,1) NOT NULL,
	[MatchId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[GovernorNameSnapshot] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[DiscordUserId] [bigint] NULL,
	[SlotType] [varchar](8) COLLATE Latin1_General_CI_AS NOT NULL,
	[Status] [varchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[CheckedIn] [bit] NOT NULL,
	[CheckedInAtUtc] [datetime2](0) NULL,
	[Source] [varchar](8) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ArkSignups] PRIMARY KEY CLUSTERED 
(
	[SignupId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]') AND name = N'IX_ArkSignups_DiscordUserId')
CREATE NONCLUSTERED INDEX [IX_ArkSignups_DiscordUserId] ON [dbo].[ArkSignups]
(
	[DiscordUserId] ASC,
	[Status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]') AND name = N'IX_ArkSignups_GovernorId')
CREATE NONCLUSTERED INDEX [IX_ArkSignups_GovernorId] ON [dbo].[ArkSignups]
(
	[GovernorId] ASC,
	[Status] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]') AND name = N'IX_ArkSignups_MatchRoster')
CREATE NONCLUSTERED INDEX [IX_ArkSignups_MatchRoster] ON [dbo].[ArkSignups]
(
	[MatchId] ASC,
	[Status] ASC,
	[SlotType] ASC,
	[CreatedAtUtc] ASC
)
INCLUDE([GovernorId],[GovernorNameSnapshot],[DiscordUserId],[CheckedIn],[CheckedInAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]') AND name = N'UX_ArkSignups_Match_Governor')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ArkSignups_Match_Governor] ON [dbo].[ArkSignups]
(
	[MatchId] ASC,
	[GovernorId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkSignups_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkSignups] ADD  CONSTRAINT [DF_ArkSignups_Status]  DEFAULT ('Active') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkSignups_CheckedIn]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkSignups] ADD  CONSTRAINT [DF_ArkSignups_CheckedIn]  DEFAULT ((0)) FOR [CheckedIn]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkSignups_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkSignups] ADD  CONSTRAINT [DF_ArkSignups_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkSignups_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkSignups] ADD  CONSTRAINT [DF_ArkSignups_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkSignups_MatchId]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups]  WITH CHECK ADD  CONSTRAINT [FK_ArkSignups_MatchId] FOREIGN KEY([MatchId])
REFERENCES [dbo].[ArkMatches] ([MatchId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkSignups_MatchId]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups] CHECK CONSTRAINT [FK_ArkSignups_MatchId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_CheckedIn]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups]  WITH CHECK ADD  CONSTRAINT [CK_ArkSignups_CheckedIn] CHECK  (([CheckedIn]=(0) OR [CheckedInAtUtc] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_CheckedIn]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups] CHECK CONSTRAINT [CK_ArkSignups_CheckedIn]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_SlotType]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups]  WITH CHECK ADD  CONSTRAINT [CK_ArkSignups_SlotType] CHECK  (([SlotType]='Sub' OR [SlotType]='Player'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_SlotType]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups] CHECK CONSTRAINT [CK_ArkSignups_SlotType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_Source]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups]  WITH CHECK ADD  CONSTRAINT [CK_ArkSignups_Source] CHECK  (([Source]='Admin' OR [Source]='Self'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_Source]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups] CHECK CONSTRAINT [CK_ArkSignups_Source]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups]  WITH CHECK ADD  CONSTRAINT [CK_ArkSignups_Status] CHECK  (([Status]='Removed' OR [Status]='Withdrawn' OR [Status]='Active'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkSignups_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]'))
ALTER TABLE [dbo].[ArkSignups] CHECK CONSTRAINT [CK_ArkSignups_Status]
