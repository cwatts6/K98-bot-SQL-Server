SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Awards]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_Awards](
	[AwardId] [bigint] IDENTITY(1,1) NOT NULL,
	[EventId] [bigint] NOT NULL,
	[SignupId] [bigint] NOT NULL,
	[GovernorId] [bigint] NOT NULL,
	[GovernorNameSnapshot] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[RequestedCommanderId] [int] NOT NULL,
	[RequestedCommanderName] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
	[AwardedRank] [int] NULL,
	[TargetScore] [bigint] NULL,
	[AwardStatus] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[WaitlistOrder] [int] NULL,
	[InternalNotes] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[PublishVersion] [int] NULL,
	[AssignedByDiscordId] [bigint] NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
	[ManualOrderOverride] [bit] NOT NULL,
	[TargetsGeneratedAtUtc] [datetime2](7) NULL,
	[TargetsGeneratedByDiscordId] [bigint] NULL,
	[TargetsOverrideLastAtUtc] [datetime2](7) NULL,
	[TargetsOverrideLastByDiscordId] [bigint] NULL,
 CONSTRAINT [PK_MGE_Awards] PRIMARY KEY CLUSTERED 
(
	[AwardId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Awards]') AND name = N'IX_MGE_Awards_Commander')
CREATE NONCLUSTERED INDEX [IX_MGE_Awards_Commander] ON [dbo].[MGE_Awards]
(
	[RequestedCommanderId] ASC,
	[GovernorId] ASC
)
INCLUDE([EventId],[AwardedRank],[AwardStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Awards]') AND name = N'IX_MGE_Awards_EventRoster')
CREATE NONCLUSTERED INDEX [IX_MGE_Awards_EventRoster] ON [dbo].[MGE_Awards]
(
	[EventId] ASC,
	[AwardStatus] ASC,
	[AwardedRank] ASC
)
INCLUDE([GovernorId],[GovernorNameSnapshot],[RequestedCommanderId],[RequestedCommanderName],[TargetScore],[WaitlistOrder]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Awards]') AND name = N'UX_MGE_Awards_EventGovernor')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_Awards_EventGovernor] ON [dbo].[MGE_Awards]
(
	[EventId] ASC,
	[GovernorId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Awards_AwardStatus]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Awards] ADD  CONSTRAINT [DF_MGE_Awards_AwardStatus]  DEFAULT ('pending') FOR [AwardStatus]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Awards_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Awards] ADD  CONSTRAINT [DF_MGE_Awards_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Awards_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Awards] ADD  CONSTRAINT [DF_MGE_Awards_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Awards_ManualOrderOverride]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Awards] ADD  CONSTRAINT [DF_MGE_Awards_ManualOrderOverride]  DEFAULT ((0)) FOR [ManualOrderOverride]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Awards_CommanderId] FOREIGN KEY([RequestedCommanderId])
REFERENCES [dbo].[MGE_Commanders] ([CommanderId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards] CHECK CONSTRAINT [FK_MGE_Awards_CommanderId]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Awards_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards] CHECK CONSTRAINT [FK_MGE_Awards_EventId]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_SignupId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards]  WITH CHECK ADD  CONSTRAINT [FK_MGE_Awards_SignupId] FOREIGN KEY([SignupId])
REFERENCES [dbo].[MGE_Signups] ([SignupId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_Awards_SignupId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards] CHECK CONSTRAINT [FK_MGE_Awards_SignupId]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Awards_AwardedRank]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Awards_AwardedRank] CHECK  (([AwardedRank] IS NULL OR [AwardedRank]>=(1) AND [AwardedRank]<=(15)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Awards_AwardedRank]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards] CHECK CONSTRAINT [CK_MGE_Awards_AwardedRank]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Awards_AwardStatus]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards]  WITH CHECK ADD  CONSTRAINT [CK_MGE_Awards_AwardStatus] CHECK  (([AwardStatus]='removed' OR [AwardStatus]='rejected' OR [AwardStatus]='waitlist' OR [AwardStatus]='awarded' OR [AwardStatus]='pending'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_MGE_Awards_AwardStatus]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_Awards]'))
ALTER TABLE [dbo].[MGE_Awards] CHECK CONSTRAINT [CK_MGE_Awards_AwardStatus]
