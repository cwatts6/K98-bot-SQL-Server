SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkBans]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkBans](
	[BanId] [bigint] IDENTITY(1,1) NOT NULL,
	[DiscordUserId] [bigint] NULL,
	[GovernorId] [bigint] NULL,
	[Reason] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[BannedArkWeekends] [int] NOT NULL,
	[StartArkWeekendDate] [date] NOT NULL,
	[EndArkWeekendDate]  AS (dateadd(day,([BannedArkWeekends]-(1))*(14),[StartArkWeekendDate])) PERSISTED,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[CreatedByDiscordId] [bigint] NULL,
	[RevokedAtUtc] [datetime2](0) NULL,
	[RevokedByDiscordId] [bigint] NULL,
 CONSTRAINT [PK_ArkBans] PRIMARY KEY CLUSTERED 
(
	[BanId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkBans]') AND name = N'IX_ArkBans_DiscordUserId_Active')
CREATE NONCLUSTERED INDEX [IX_ArkBans_DiscordUserId_Active] ON [dbo].[ArkBans]
(
	[DiscordUserId] ASC,
	[EndArkWeekendDate] ASC
)
WHERE ([RevokedAtUtc] IS NULL AND [DiscordUserId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkBans]') AND name = N'IX_ArkBans_GovernorId_Active')
CREATE NONCLUSTERED INDEX [IX_ArkBans_GovernorId_Active] ON [dbo].[ArkBans]
(
	[GovernorId] ASC,
	[EndArkWeekendDate] ASC
)
WHERE ([RevokedAtUtc] IS NULL AND [GovernorId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkBans_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkBans] ADD  CONSTRAINT [DF_ArkBans_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkBans_Target]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkBans]'))
ALTER TABLE [dbo].[ArkBans]  WITH CHECK ADD  CONSTRAINT [CK_ArkBans_Target] CHECK  (([DiscordUserId] IS NOT NULL OR [GovernorId] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkBans_Target]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkBans]'))
ALTER TABLE [dbo].[ArkBans] CHECK CONSTRAINT [CK_ArkBans_Target]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkBans_Weekends]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkBans]'))
ALTER TABLE [dbo].[ArkBans]  WITH CHECK ADD  CONSTRAINT [CK_ArkBans_Weekends] CHECK  (([BannedArkWeekends]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkBans_Weekends]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkBans]'))
ALTER TABLE [dbo].[ArkBans] CHECK CONSTRAINT [CK_ArkBans_Weekends]
