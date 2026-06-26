SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DiscordUserProfilePreference](
	[DiscordUserID] [bigint] NOT NULL,
	[TimezoneName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[LocationCountryCode] [nvarchar](2) COLLATE Latin1_General_CI_AS NULL,
	[PreferredLanguageTag] [nvarchar](35) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedAtUtc] [datetime2](3) NOT NULL,
	[UpdatedByDiscordUserID] [bigint] NULL,
 CONSTRAINT [PK_DiscordUserProfilePreference] PRIMARY KEY CLUSTERED 
(
	[DiscordUserID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DiscordUserProfilePreference_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordUserProfilePreference] ADD  CONSTRAINT [DF_DiscordUserProfilePreference_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DiscordUserProfilePreference_UpdatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordUserProfilePreference] ADD  CONSTRAINT [DF_DiscordUserProfilePreference_UpdatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_DiscordUserID]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference]  WITH CHECK ADD  CONSTRAINT [CK_DiscordUserProfilePreference_DiscordUserID] CHECK  (([DiscordUserID]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_DiscordUserID]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference] CHECK CONSTRAINT [CK_DiscordUserProfilePreference_DiscordUserID]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_TimezoneName]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference]  WITH CHECK ADD  CONSTRAINT [CK_DiscordUserProfilePreference_TimezoneName] CHECK  (([TimezoneName] IS NULL OR (len(ltrim(rtrim([TimezoneName])))>(0) AND [TimezoneName] NOT LIKE N'% %' AND patindex(N'%[^A-Za-z0-9_+/.-]%', [TimezoneName] COLLATE Latin1_General_BIN2)=(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_TimezoneName]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference] CHECK CONSTRAINT [CK_DiscordUserProfilePreference_TimezoneName]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_LocationCountryCode]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference]  WITH CHECK ADD  CONSTRAINT [CK_DiscordUserProfilePreference_LocationCountryCode] CHECK  (([LocationCountryCode] IS NULL OR [LocationCountryCode] COLLATE Latin1_General_BIN2 like N'[A-Z][A-Z]'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_LocationCountryCode]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference] CHECK CONSTRAINT [CK_DiscordUserProfilePreference_LocationCountryCode]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_PreferredLanguageTag]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference]  WITH CHECK ADD  CONSTRAINT [CK_DiscordUserProfilePreference_PreferredLanguageTag] CHECK  (([PreferredLanguageTag] IS NULL OR (len(ltrim(rtrim([PreferredLanguageTag])))>(0) AND patindex(N'%[^A-Za-z0-9-]%', [PreferredLanguageTag] COLLATE Latin1_General_BIN2)=(0) AND [PreferredLanguageTag] NOT LIKE N'-%' AND [PreferredLanguageTag] NOT LIKE N'%-' AND [PreferredLanguageTag] NOT LIKE N'%--%')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_PreferredLanguageTag]') AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]'))
ALTER TABLE [dbo].[DiscordUserProfilePreference] CHECK CONSTRAINT [CK_DiscordUserProfilePreference_PreferredLanguageTag]
