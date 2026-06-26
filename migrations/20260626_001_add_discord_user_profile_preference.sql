/*
MigrationId: 20260626_001_add_discord_user_profile_preference
Purpose: Add Discord-user-level profile preference storage for player self-service
Author: cwatts
CreatedUtc: 2026-06-26
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.DiscordUserProfilePreference', N'U') AS ObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.DiscordUserProfilePreference', N'U') AS ObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
      AND type = N'U'
)
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
    ) ON [PRIMARY];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[DF_DiscordUserProfilePreference_CreatedAtUtc]')
      AND type = N'D'
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    ADD CONSTRAINT [DF_DiscordUserProfilePreference_CreatedAtUtc]
    DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.objects
    WHERE object_id = OBJECT_ID(N'[dbo].[DF_DiscordUserProfilePreference_UpdatedAtUtc]')
      AND type = N'D'
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    ADD CONSTRAINT [DF_DiscordUserProfilePreference_UpdatedAtUtc]
    DEFAULT (sysutcdatetime()) FOR [UpdatedAtUtc];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_DiscordUserID]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference] WITH CHECK
    ADD CONSTRAINT [CK_DiscordUserProfilePreference_DiscordUserID]
    CHECK ([DiscordUserID] > 0);
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_DiscordUserID]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    CHECK CONSTRAINT [CK_DiscordUserProfilePreference_DiscordUserID];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_TimezoneName]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference] WITH CHECK
    ADD CONSTRAINT [CK_DiscordUserProfilePreference_TimezoneName]
    CHECK (
        [TimezoneName] IS NULL
        OR (
            LEN(LTRIM(RTRIM([TimezoneName]))) > 0
            AND [TimezoneName] NOT LIKE N'% %'
            AND PATINDEX(
                N'%[^A-Za-z0-9_+/.-]%',
                [TimezoneName] COLLATE Latin1_General_BIN2
            ) = 0
        )
    );
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_TimezoneName]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    CHECK CONSTRAINT [CK_DiscordUserProfilePreference_TimezoneName];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_LocationCountryCode]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference] WITH CHECK
    ADD CONSTRAINT [CK_DiscordUserProfilePreference_LocationCountryCode]
    CHECK (
        [LocationCountryCode] IS NULL
        OR [LocationCountryCode] COLLATE Latin1_General_BIN2 LIKE N'[A-Z][A-Z]'
    );
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_LocationCountryCode]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    CHECK CONSTRAINT [CK_DiscordUserProfilePreference_LocationCountryCode];
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_PreferredLanguageTag]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference] WITH CHECK
    ADD CONSTRAINT [CK_DiscordUserProfilePreference_PreferredLanguageTag]
    CHECK (
        [PreferredLanguageTag] IS NULL
        OR (
            LEN(LTRIM(RTRIM([PreferredLanguageTag]))) > 0
            AND PATINDEX(
                N'%[^A-Za-z0-9-]%',
                [PreferredLanguageTag] COLLATE Latin1_General_BIN2
            ) = 0
            AND [PreferredLanguageTag] NOT LIKE N'-%'
            AND [PreferredLanguageTag] NOT LIKE N'%-'
            AND [PreferredLanguageTag] NOT LIKE N'%--%'
        )
    );
END
GO

IF EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE object_id = OBJECT_ID(N'[dbo].[CK_DiscordUserProfilePreference_PreferredLanguageTag]')
      AND parent_object_id = OBJECT_ID(N'[dbo].[DiscordUserProfilePreference]')
)
BEGIN
    ALTER TABLE [dbo].[DiscordUserProfilePreference]
    CHECK CONSTRAINT [CK_DiscordUserProfilePreference_PreferredLanguageTag];
END
GO
