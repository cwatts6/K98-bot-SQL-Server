SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkConfig]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkConfig](
	[ConfigId] [int] IDENTITY(1,1) NOT NULL,
	[AnchorWeekendDate] [date] NOT NULL,
	[FrequencyWeekends] [int] NOT NULL,
	[AllowedDaysJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[AllowedTimeSlotsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[SignupCloseDay] [varchar](9) COLLATE Latin1_General_CI_AS NOT NULL,
	[SignupCloseTimeUtc] [time](0) NOT NULL,
	[PlayersCap] [int] NOT NULL,
	[SubsCap] [int] NOT NULL,
	[CheckInActivationOffsetHours] [int] NOT NULL,
	[ReminderIntervalsHoursJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[ReminderDailyNudgeEnabled] [bit] NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[UpdatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_ArkConfig] PRIMARY KEY CLUSTERED 
(
	[ConfigId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkConfig_ReminderDailyNudgeEnabled]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkConfig] ADD  CONSTRAINT [DF_ArkConfig_ReminderDailyNudgeEnabled]  DEFAULT ((1)) FOR [ReminderDailyNudgeEnabled]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkConfig_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkConfig] ADD  CONSTRAINT [DF_ArkConfig_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkConfig_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkConfig] ADD  CONSTRAINT [DF_ArkConfig_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_AllowedDaysJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig]  WITH CHECK ADD  CONSTRAINT [CK_ArkConfig_AllowedDaysJson] CHECK  ((isjson([AllowedDaysJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_AllowedDaysJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig] CHECK CONSTRAINT [CK_ArkConfig_AllowedDaysJson]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_AllowedTimeSlotsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig]  WITH CHECK ADD  CONSTRAINT [CK_ArkConfig_AllowedTimeSlotsJson] CHECK  ((isjson([AllowedTimeSlotsJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_AllowedTimeSlotsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig] CHECK CONSTRAINT [CK_ArkConfig_AllowedTimeSlotsJson]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_FrequencyWeekends]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig]  WITH CHECK ADD  CONSTRAINT [CK_ArkConfig_FrequencyWeekends] CHECK  (([FrequencyWeekends]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_FrequencyWeekends]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig] CHECK CONSTRAINT [CK_ArkConfig_FrequencyWeekends]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_ReminderIntervalsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig]  WITH CHECK ADD  CONSTRAINT [CK_ArkConfig_ReminderIntervalsJson] CHECK  ((isjson([ReminderIntervalsHoursJson])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ArkConfig_ReminderIntervalsJson]') AND parent_object_id = OBJECT_ID(N'[dbo].[ArkConfig]'))
ALTER TABLE [dbo].[ArkConfig] CHECK CONSTRAINT [CK_ArkConfig_ReminderIntervalsJson]
