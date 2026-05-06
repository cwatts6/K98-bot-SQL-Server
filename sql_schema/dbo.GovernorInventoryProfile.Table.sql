SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorInventoryProfile]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorInventoryProfile](
	[GovernorID] [bigint] NOT NULL,
	[VipLevelCode] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[VipLevelLabel] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[UpdatedByDiscordUserID] [bigint] NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_GovernorInventoryProfile] PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_GovernorInventoryProfile_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[GovernorInventoryProfile] ADD  CONSTRAINT [DF_GovernorInventoryProfile_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_GovernorInventoryProfile_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[GovernorInventoryProfile] ADD  CONSTRAINT [DF_GovernorInventoryProfile_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorInventoryProfile_VipLevelCode]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorInventoryProfile]'))
ALTER TABLE [dbo].[GovernorInventoryProfile]  WITH CHECK ADD  CONSTRAINT [CK_GovernorInventoryProfile_VipLevelCode] CHECK  (([VipLevelCode] IS NULL OR ([VipLevelCode]=N'SVIP' OR [VipLevelCode]=N'VIP_19' OR [VipLevelCode]=N'VIP_18' OR [VipLevelCode]=N'VIP_17' OR [VipLevelCode]=N'VIP_16' OR [VipLevelCode]=N'VIP_15' OR [VipLevelCode]=N'VIP_14_OR_LESS')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorInventoryProfile_VipLevelCode]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorInventoryProfile]'))
ALTER TABLE [dbo].[GovernorInventoryProfile] CHECK CONSTRAINT [CK_GovernorInventoryProfile_VipLevelCode]
