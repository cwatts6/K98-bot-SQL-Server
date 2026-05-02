SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InventoryReportPreference]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[InventoryReportPreference](
	[DiscordUserID] [bigint] NOT NULL,
	[Visibility] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_InventoryReportPreference] PRIMARY KEY CLUSTERED 
(
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryReportPreference_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryReportPreference] ADD  CONSTRAINT [DF_InventoryReportPreference_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryReportPreference_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryReportPreference] ADD  CONSTRAINT [DF_InventoryReportPreference_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryReportPreference_Visibility]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryReportPreference]'))
ALTER TABLE [dbo].[InventoryReportPreference]  WITH CHECK ADD  CONSTRAINT [CK_InventoryReportPreference_Visibility] CHECK  (([Visibility]=N'public' OR [Visibility]=N'only_me'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryReportPreference_Visibility]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryReportPreference]'))
ALTER TABLE [dbo].[InventoryReportPreference] CHECK CONSTRAINT [CK_InventoryReportPreference_Visibility]
