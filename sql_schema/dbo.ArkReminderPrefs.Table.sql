SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkReminderPrefs]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkReminderPrefs](
	[DiscordUserId] [bigint] NOT NULL,
	[OptOutAll] [bit] NOT NULL,
	[OptOutIntervalsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ArkReminderPrefs] PRIMARY KEY CLUSTERED 
(
	[DiscordUserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkReminderPrefs_OptOutAll]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkReminderPrefs] ADD  CONSTRAINT [DF_ArkReminderPrefs_OptOutAll]  DEFAULT ((0)) FOR [OptOutAll]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkReminderPrefs_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkReminderPrefs] ADD  CONSTRAINT [DF_ArkReminderPrefs_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkReminderPrefs_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkReminderPrefs] ADD  CONSTRAINT [DF_ArkReminderPrefs_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkReminderPrefs_OptOutIntervalsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkReminderPrefs]'))
ALTER TABLE [dbo].[ArkReminderPrefs]  WITH CHECK ADD  CONSTRAINT [CK_ArkReminderPrefs_OptOutIntervalsJson] CHECK  (([OptOutIntervalsJson] IS NULL OR isjson([OptOutIntervalsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkReminderPrefs_OptOutIntervalsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkReminderPrefs]'))
ALTER TABLE [dbo].[ArkReminderPrefs] CHECK CONSTRAINT [CK_ArkReminderPrefs_OptOutIntervalsJson]
