SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkMatchTeams](
	[ArkMatchTeamId] [bigint] IDENTITY(1,1) NOT NULL,
	[MatchId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[TeamNumber] [int] NOT NULL,
	[IsDraft] [bit] NOT NULL,
	[IsFinal] [bit] NOT NULL,
	[Source] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[CreatedByDiscordId] [bigint] NULL,
	[UpdatedByDiscordId] [bigint] NULL,
	[CreatedAtUtc] [datetime2](7) NOT NULL,
	[UpdatedAtUtc] [datetime2](7) NOT NULL,
	[FinalizedAtUtc] [datetime2](7) NULL,
	[FinalizedByDiscordId] [bigint] NULL,
 CONSTRAINT [PK_ArkMatchTeams] PRIMARY KEY CLUSTERED 
(
	[ArkMatchTeamId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]') AND name = N'IX_ArkMatchTeams_MatchStateTeam')
CREATE NONCLUSTERED INDEX [IX_ArkMatchTeams_MatchStateTeam] ON [dbo].[ArkMatchTeams]
(
	[MatchId] ASC,
	[IsDraft] ASC,
	[IsFinal] ASC,
	[TeamNumber] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]') AND name = N'UX_ArkMatchTeams_Draft_MatchGovernor')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ArkMatchTeams_Draft_MatchGovernor] ON [dbo].[ArkMatchTeams]
(
	[MatchId] ASC,
	[GovernorId] ASC
)
WHERE ([IsDraft]=(1) AND [IsFinal]=(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]') AND name = N'UX_ArkMatchTeams_Final_MatchGovernor')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ArkMatchTeams_Final_MatchGovernor] ON [dbo].[ArkMatchTeams]
(
	[MatchId] ASC,
	[GovernorId] ASC
)
WHERE ([IsDraft]=(0) AND [IsFinal]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatchTeams_IsDraft]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatchTeams] ADD  CONSTRAINT [DF_ArkMatchTeams_IsDraft]  DEFAULT ((1)) FOR [IsDraft]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatchTeams_IsFinal]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatchTeams] ADD  CONSTRAINT [DF_ArkMatchTeams_IsFinal]  DEFAULT ((0)) FOR [IsFinal]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatchTeams_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatchTeams] ADD  CONSTRAINT [DF_ArkMatchTeams_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkMatchTeams_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkMatchTeams] ADD  CONSTRAINT [DF_ArkMatchTeams_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkMatchTeams_Match]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams]  WITH CHECK ADD  CONSTRAINT [FK_ArkMatchTeams_Match] FOREIGN KEY([MatchId])
REFERENCES [dbo].[ArkMatches] ([MatchId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkMatchTeams_Match]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams] CHECK CONSTRAINT [FK_ArkMatchTeams_Match]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatchTeams_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams]  WITH CHECK ADD  CONSTRAINT [CK_ArkMatchTeams_State] CHECK  (([IsDraft]=(1) AND [IsFinal]=(0) OR [IsDraft]=(0) AND [IsFinal]=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatchTeams_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams] CHECK CONSTRAINT [CK_ArkMatchTeams_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatchTeams_TeamNumber]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams]  WITH CHECK ADD  CONSTRAINT [CK_ArkMatchTeams_TeamNumber] CHECK  (([TeamNumber]=(2) OR [TeamNumber]=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkMatchTeams_TeamNumber]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatchTeams]'))
ALTER TABLE [dbo].[ArkMatchTeams] CHECK CONSTRAINT [CK_ArkMatchTeams_TeamNumber]
