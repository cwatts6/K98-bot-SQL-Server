SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkAuditLog](
	[LogId] [bigint] IDENTITY(1,1) NOT NULL,
	[ActionType] [varchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[ActorDiscordId] [bigint] NOT NULL,
	[MatchId] [bigint] NULL,
	[GovernorId] [bigint] NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ArkAuditLog] PRIMARY KEY CLUSTERED 
(
	[LogId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]') AND name = N'IX_ArkAuditLog_Governor')
CREATE NONCLUSTERED INDEX [IX_ArkAuditLog_Governor] ON [dbo].[ArkAuditLog]
(
	[GovernorId] ASC,
	[CreatedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]') AND name = N'IX_ArkAuditLog_Match')
CREATE NONCLUSTERED INDEX [IX_ArkAuditLog_Match] ON [dbo].[ArkAuditLog]
(
	[MatchId] ASC,
	[CreatedAtUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkAuditLog_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkAuditLog] ADD  CONSTRAINT [DF_ArkAuditLog_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkAuditLog_MatchId]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]'))
ALTER TABLE [dbo].[ArkAuditLog]  WITH CHECK ADD  CONSTRAINT [FK_ArkAuditLog_MatchId] FOREIGN KEY([MatchId])
REFERENCES [dbo].[ArkMatches] ([MatchId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ArkAuditLog_MatchId]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]'))
ALTER TABLE [dbo].[ArkAuditLog] CHECK CONSTRAINT [FK_ArkAuditLog_MatchId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkAuditLog_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]'))
ALTER TABLE [dbo].[ArkAuditLog]  WITH CHECK ADD  CONSTRAINT [CK_ArkAuditLog_DetailsJson] CHECK  (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkAuditLog_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]'))
ALTER TABLE [dbo].[ArkAuditLog] CHECK CONSTRAINT [CK_ArkAuditLog_DetailsJson]
