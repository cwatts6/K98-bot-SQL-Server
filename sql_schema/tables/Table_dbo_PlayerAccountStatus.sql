SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PlayerAccountStatus](
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[Status] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL,
	[UpdatedAt] [datetime2](3) NOT NULL,
	[AccountType] [nvarchar](10) COLLATE Latin1_General_CI_AS NOT NULL,
	[Main_GovernorID] [bigint] NULL,
	[Role] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_PlayerAccountStatus] PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]') AND name = N'IX_PAS_Gov_AccType')
CREATE NONCLUSTERED INDEX [IX_PAS_Gov_AccType] ON [dbo].[PlayerAccountStatus]
(
	[GovernorID] ASC,
	[AccountType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]') AND name = N'IX_PlayerAccountStatus_MainGov')
CREATE NONCLUSTERED INDEX [IX_PlayerAccountStatus_MainGov] ON [dbo].[PlayerAccountStatus]
(
	[Main_GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerAccountStatus_Status]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerAccountStatus] ADD  CONSTRAINT [DF_PlayerAccountStatus_Status]  DEFAULT (N'Fighter') FOR [Status]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerAccountStatus_UpdatedAt]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerAccountStatus] ADD  CONSTRAINT [DF_PlayerAccountStatus_UpdatedAt]  DEFAULT (sysutcdatetime()) FOR [UpdatedAt]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerAccountStatus_AccountType]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerAccountStatus] ADD  CONSTRAINT [DF_PlayerAccountStatus_AccountType]  DEFAULT ('Main') FOR [AccountType]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_PlayerAccountStatus_MainGovernor]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus]  WITH CHECK ADD  CONSTRAINT [FK_PlayerAccountStatus_MainGovernor] FOREIGN KEY([Main_GovernorID])
REFERENCES [dbo].[PlayerAccountStatus] ([GovernorID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_PlayerAccountStatus_MainGovernor]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus] CHECK CONSTRAINT [FK_PlayerAccountStatus_MainGovernor]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_PlayerAccountStatus_AccountType]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus]  WITH CHECK ADD  CONSTRAINT [CK_PlayerAccountStatus_AccountType] CHECK  (([AccountType]=N'Bank' OR [AccountType]=N'Farm' OR [AccountType]=N'Alt' OR [AccountType]=N'Main'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_PlayerAccountStatus_AccountType]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus] CHECK CONSTRAINT [CK_PlayerAccountStatus_AccountType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_PlayerAccountStatus_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus]  WITH CHECK ADD  CONSTRAINT [CK_PlayerAccountStatus_Status] CHECK  (([Status]=N'Fighter' OR [Status]=N'Farm' OR [Status]=N'Migrate' OR [Status]=N'Power Down' OR [Status]=N'Offline' OR [Status]=N'Exempt' OR [Status]=N'Alt'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_PlayerAccountStatus_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus]'))
ALTER TABLE [dbo].[PlayerAccountStatus] CHECK CONSTRAINT [CK_PlayerAccountStatus_Status]
