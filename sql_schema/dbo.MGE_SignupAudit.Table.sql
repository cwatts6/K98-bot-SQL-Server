SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_SignupAudit](
	[AuditId] [bigint] IDENTITY(1,1) NOT NULL,
	[SignupId] [bigint] NOT NULL,
	[EventId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[ActionType] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[ActorDiscordId] [bigint] NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_SignupAudit] PRIMARY KEY CLUSTERED 
(
	[AuditId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]') AND name = N'IX_MGE_SignupAudit_Event')
CREATE NONCLUSTERED INDEX [IX_MGE_SignupAudit_Event] ON [dbo].[MGE_SignupAudit]
(
	[EventId] ASC,
	[CreatedUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]') AND name = N'IX_MGE_SignupAudit_Governor')
CREATE NONCLUSTERED INDEX [IX_MGE_SignupAudit_Governor] ON [dbo].[MGE_SignupAudit]
(
	[GovernorId] ASC,
	[CreatedUtc] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_SignupAudit_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_SignupAudit] ADD  CONSTRAINT [DF_MGE_SignupAudit_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_SignupAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit]  WITH CHECK ADD  CONSTRAINT [FK_MGE_SignupAudit_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_SignupAudit_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit] CHECK CONSTRAINT [FK_MGE_SignupAudit_EventId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_SignupAudit_ActionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit]  WITH CHECK ADD  CONSTRAINT [CK_MGE_SignupAudit_ActionType] CHECK  (([ActionType]='admin_remove' OR [ActionType]='admin_add' OR [ActionType]='admin_edit' OR [ActionType]='withdraw' OR [ActionType]='edit' OR [ActionType]='create' OR [ActionType]='bulk_delete_open_switch'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_SignupAudit_ActionType]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit] CHECK CONSTRAINT [CK_MGE_SignupAudit_ActionType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_SignupAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit]  WITH CHECK ADD  CONSTRAINT [CK_MGE_SignupAudit_DetailsJson] CHECK  (([DetailsJson] IS NULL OR isjson([DetailsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_SignupAudit_DetailsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_SignupAudit]'))
ALTER TABLE [dbo].[MGE_SignupAudit] CHECK CONSTRAINT [CK_MGE_SignupAudit_DetailsJson]
