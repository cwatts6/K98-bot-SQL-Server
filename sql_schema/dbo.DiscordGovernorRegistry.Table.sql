SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DiscordGovernorRegistry](
	[RegistrationID] [bigint] IDENTITY(1,1) NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[DiscordName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[AccountType] [nvarchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[RegistrationStatus] [nvarchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUTC] [datetime2](0) NOT NULL,
	[UpdatedAtUTC] [datetime2](0) NOT NULL,
	[CreatedByDiscordID] [bigint] NULL,
	[UpdatedByDiscordID] [bigint] NULL,
	[Provenance] [nvarchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_DiscordGovernorRegistry] PRIMARY KEY CLUSTERED 
(
	[RegistrationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]') AND name = N'IX_DGR_DiscordUserID')
CREATE NONCLUSTERED INDEX [IX_DGR_DiscordUserID] ON [dbo].[DiscordGovernorRegistry]
(
	[DiscordUserID] ASC
)
INCLUDE([GovernorID],[AccountType],[RegistrationStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]') AND name = N'IX_DGR_GovernorID')
CREATE NONCLUSTERED INDEX [IX_DGR_GovernorID] ON [dbo].[DiscordGovernorRegistry]
(
	[GovernorID] ASC
)
INCLUDE([DiscordUserID],[AccountType],[RegistrationStatus]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]') AND name = N'UQ_DGR_ActiveGovernor')
CREATE UNIQUE NONCLUSTERED INDEX [UQ_DGR_ActiveGovernor] ON [dbo].[DiscordGovernorRegistry]
(
	[GovernorID] ASC
)
WHERE ([RegistrationStatus]='Active')
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]') AND name = N'UQ_DGR_ActiveSlot')
CREATE UNIQUE NONCLUSTERED INDEX [UQ_DGR_ActiveSlot] ON [dbo].[DiscordGovernorRegistry]
(
	[DiscordUserID] ASC,
	[AccountType] ASC
)
WHERE ([RegistrationStatus]='Active')
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DGR_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordGovernorRegistry] ADD  CONSTRAINT [DF_DGR_Status]  DEFAULT ('Active') FOR [RegistrationStatus]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DGR_CreatedAt]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordGovernorRegistry] ADD  CONSTRAINT [DF_DGR_CreatedAt]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUTC]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DGR_UpdatedAt]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordGovernorRegistry] ADD  CONSTRAINT [DF_DGR_UpdatedAt]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUTC]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DGR_Provenance]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordGovernorRegistry] ADD  CONSTRAINT [DF_DGR_Provenance]  DEFAULT ('bot_command') FOR [Provenance]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_AccountType]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry]  WITH CHECK ADD  CONSTRAINT [CK_DGR_AccountType] CHECK  (([AccountType]='Farm 20' OR [AccountType]='Farm 19' OR [AccountType]='Farm 18' OR [AccountType]='Farm 17' OR [AccountType]='Farm 16' OR [AccountType]='Farm 15' OR [AccountType]='Farm 14' OR [AccountType]='Farm 13' OR [AccountType]='Farm 12' OR [AccountType]='Farm 11' OR [AccountType]='Farm 10' OR [AccountType]='Farm 9' OR [AccountType]='Farm 8' OR [AccountType]='Farm 7' OR [AccountType]='Farm 6' OR [AccountType]='Farm 5' OR [AccountType]='Farm 4' OR [AccountType]='Farm 3' OR [AccountType]='Farm 2' OR [AccountType]='Farm 1' OR [AccountType]='Alt 5' OR [AccountType]='Alt 4' OR [AccountType]='Alt 3' OR [AccountType]='Alt 2' OR [AccountType]='Alt 1' OR [AccountType]='Main'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_AccountType]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry] CHECK CONSTRAINT [CK_DGR_AccountType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_Provenance]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry]  WITH CHECK ADD  CONSTRAINT [CK_DGR_Provenance] CHECK  (([Provenance]='migration' OR [Provenance]='import' OR [Provenance]='admin_command' OR [Provenance]='bot_command'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_Provenance]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry] CHECK CONSTRAINT [CK_DGR_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_RegistrationStatus]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry]  WITH CHECK ADD  CONSTRAINT [CK_DGR_RegistrationStatus] CHECK  (([RegistrationStatus]='Superseded' OR [RegistrationStatus]='Removed' OR [RegistrationStatus]='Active'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DGR_RegistrationStatus]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordGovernorRegistry]'))
ALTER TABLE [dbo].[DiscordGovernorRegistry] CHECK CONSTRAINT [CK_DGR_RegistrationStatus]
