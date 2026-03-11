SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Signups]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_Signups](
	[SignupId] [bigint] IDENTITY(1,1) NOT NULL,
	[EventId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[GovernorNameSnapshot] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[DiscordUserId] [bigint] NULL,
	[RequestPriority] [varchar](10) COLLATE Latin1_General_CI_AS NOT NULL,
	[PreferredRankBand] [varchar](20) COLLATE Latin1_General_CI_AS NULL,
	[RequestedCommanderId] [int] NOT NULL,
	[RequestedCommanderName] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
	[CurrentHeads] [int] NOT NULL,
	[KingdomRole] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[GearText] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[ArmamentText] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[GearAttachmentUrl] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[GearAttachmentFilename] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[ArmamentAttachmentUrl] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[ArmamentAttachmentFilename] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[IsActive] [bit] NOT NULL,
	[Source] [nvarchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_Signups] PRIMARY KEY CLUSTERED 
(
	[SignupId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Signups]') AND name = N'IX_MGE_Signups_DiscordUserId')
CREATE NONCLUSTERED INDEX [IX_MGE_Signups_DiscordUserId] ON [dbo].[MGE_Signups]
(
	[DiscordUserId] ASC,
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Signups]') AND name = N'IX_MGE_Signups_Event_Active')
CREATE NONCLUSTERED INDEX [IX_MGE_Signups_Event_Active] ON [dbo].[MGE_Signups]
(
	[EventId] ASC,
	[IsActive] ASC,
	[CreatedUtc] ASC
)
INCLUDE([GovernorId],[GovernorNameSnapshot],[RequestPriority],[RequestedCommanderId],[RequestedCommanderName],[CurrentHeads],[DiscordUserId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Signups]') AND name = N'IX_MGE_Signups_GovernorId')
CREATE NONCLUSTERED INDEX [IX_MGE_Signups_GovernorId] ON [dbo].[MGE_Signups]
(
	[GovernorId] ASC,
	[IsActive] ASC
)
INCLUDE([EventId],[RequestedCommanderId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Signups]') AND name = N'UX_MGE_Signups_EventGovernor_Active')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_Signups_EventGovernor_Active] ON [dbo].[MGE_Signups]
(
	[EventId] ASC,
	[GovernorId] ASC
)
WHERE ([IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Signups_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Signups] ADD  CONSTRAINT [DF_MGE_Signups_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Signups_Source]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Signups] ADD  CONSTRAINT [DF_MGE_Signups_Source]  DEFAULT ('discord') FOR [Source]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Signups_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Signups] ADD  CONSTRAINT [DF_MGE_Signups_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Signups_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Signups] ADD  CONSTRAINT [DF_MGE_Signups_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Signups_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Signups_CommanderId] FOREIGN KEY([RequestedCommanderId])
REFERENCES [dbo].[MGE_Commanders] ([CommanderId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Signups_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [FK_MGE_Signups_CommanderId]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Signups_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Signups_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Signups_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [FK_MGE_Signups_EventId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_CurrentHeads]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Signups_CurrentHeads] CHECK  (([CurrentHeads]>=(0) AND [CurrentHeads]<=(680)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_CurrentHeads]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [CK_MGE_Signups_CurrentHeads]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_PreferredRankBand]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Signups_PreferredRankBand] CHECK  (([PreferredRankBand] IS NULL OR [PreferredRankBand]='no_preference' OR [PreferredRankBand]='11-15' OR [PreferredRankBand]='6-10' OR [PreferredRankBand]='1-5'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_PreferredRankBand]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [CK_MGE_Signups_PreferredRankBand]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_RequestPriority]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Signups_RequestPriority] CHECK  (([RequestPriority]='Low' OR [RequestPriority]='Medium' OR [RequestPriority]='High'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_RequestPriority]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [CK_MGE_Signups_RequestPriority]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_Source]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Signups_Source] CHECK  (([Source]='admin' OR [Source]='discord'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Signups_Source]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Signups]'))
ALTER TABLE [dbo].[MGE_Signups] CHECK CONSTRAINT [CK_MGE_Signups_Source]
