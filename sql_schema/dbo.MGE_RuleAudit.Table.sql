SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_RuleAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_RuleAudit](
	[AuditId] [bigint] IDENTITY(1,1) NOT NULL,
	[EventId] [bigint] NOT NULL,
	[ActorDiscordId] [bigint] NULL,
	[ActionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[OldRuleMode] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[NewRuleMode] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[OldRulesText] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[NewRulesText] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_RuleAudit] PRIMARY KEY CLUSTERED 
(
	[AuditId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_RuleAudit]') AND name = N'IX_MGE_RuleAudit_Event')
CREATE NONCLUSTERED INDEX [IX_MGE_RuleAudit_Event] ON [dbo].[MGE_RuleAudit]
(
	[EventId] ASC,
	[CreatedUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_RuleAudit_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_RuleAudit] ADD  CONSTRAINT [DF_MGE_RuleAudit_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_RuleAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_RuleAudit]'))
ALTER TABLE [dbo].[MGE_RuleAudit]  WITH CHECK ADD  CONSTRAINT [FK_MGE_RuleAudit_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_RuleAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_RuleAudit]'))
ALTER TABLE [dbo].[MGE_RuleAudit] CHECK CONSTRAINT [FK_MGE_RuleAudit_EventId]
