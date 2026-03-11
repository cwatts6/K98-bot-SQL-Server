SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_AwardAudit](
	[AuditId] [bigint] IDENTITY(1,1) NOT NULL,
	[AwardId] [bigint] NOT NULL,
	[EventId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[ActionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[ActorDiscordId] [bigint] NULL,
	[OldRank] [int] NULL,
	[NewRank] [int] NULL,
	[OldStatus] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[NewStatus] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[OldTargetScore] [bigint] NULL,
	[NewTargetScore] [bigint] NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_AwardAudit] PRIMARY KEY CLUSTERED 
(
	[AuditId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]') AND name = N'IX_MGE_AwardAudit_Award')
CREATE NONCLUSTERED INDEX [IX_MGE_AwardAudit_Award] ON [dbo].[MGE_AwardAudit]
(
	[AwardId] ASC,
	[CreatedUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]') AND name = N'IX_MGE_AwardAudit_Event')
CREATE NONCLUSTERED INDEX [IX_MGE_AwardAudit_Event] ON [dbo].[MGE_AwardAudit]
(
	[EventId] ASC,
	[CreatedUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_AwardAudit_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_AwardAudit] ADD  CONSTRAINT [DF_MGE_AwardAudit_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_AwardAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]'))
ALTER TABLE [dbo].[MGE_AwardAudit]  WITH CHECK ADD  CONSTRAINT [FK_MGE_AwardAudit_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_AwardAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]'))
ALTER TABLE [dbo].[MGE_AwardAudit] CHECK CONSTRAINT [FK_MGE_AwardAudit_EventId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_AwardAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]'))
ALTER TABLE [dbo].[MGE_AwardAudit]  WITH CHECK ADD  CONSTRAINT [CK_MGE_AwardAudit_DetailsJson] CHECK  (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_AwardAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_AwardAudit]'))
ALTER TABLE [dbo].[MGE_AwardAudit] CHECK CONSTRAINT [CK_MGE_AwardAudit_DetailsJson]
