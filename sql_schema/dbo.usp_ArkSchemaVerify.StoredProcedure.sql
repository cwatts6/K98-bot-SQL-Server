SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_ArkSchemaVerify]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_ArkSchemaVerify] AS' 
END
ALTER PROCEDURE [dbo].[usp_ArkSchemaVerify]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Errors TABLE ([ErrorMessage] nvarchar(4000));

    IF OBJECT_ID(N'[dbo].[ArkAlliances]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkAlliances');

    IF OBJECT_ID(N'[dbo].[ArkMatches]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkMatches');

    IF OBJECT_ID(N'[dbo].[ArkSignups]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkSignups');

    IF OBJECT_ID(N'[dbo].[ArkBans]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkBans');

    IF OBJECT_ID(N'[dbo].[ArkConfig]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkConfig');

    IF OBJECT_ID(N'[dbo].[ArkReminderPrefs]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkReminderPrefs');

    IF OBJECT_ID(N'[dbo].[ArkAuditLog]', N'U') IS NULL
        INSERT INTO @Errors VALUES (N'Missing table: dbo.ArkAuditLog');

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkAlliances]')
          AND name = N'RegistrationChannelId'
    )
        INSERT INTO @Errors VALUES (N'Missing column: dbo.ArkAlliances.RegistrationChannelId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkAlliances]')
          AND name = N'ConfirmationChannelId'
    )
        INSERT INTO @Errors VALUES (N'Missing column: dbo.ArkAlliances.ConfirmationChannelId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]')
          AND name = N'ConfirmationChannelId'
    )
        INSERT INTO @Errors VALUES (N'Missing column: dbo.ArkMatches.ConfirmationChannelId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.columns
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]')
          AND name = N'ConfirmationMessageId'
    )
        INSERT INTO @Errors VALUES (N'Missing column: dbo.ArkMatches.ConfirmationMessageId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = N'FK_ArkMatches_Alliance'
          AND parent_object_id = OBJECT_ID(N'[dbo].[ArkMatches]')
    )
        INSERT INTO @Errors VALUES (N'Missing FK: FK_ArkMatches_Alliance');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]')
          AND name = N'UX_ArkMatches_Alliance_Weekend'
    )
        INSERT INTO @Errors VALUES (N'Missing unique index: UX_ArkMatches_Alliance_Weekend');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]')
          AND name = N'UX_ArkSignups_Match_Governor'
    )
        INSERT INTO @Errors VALUES (N'Missing unique index: UX_ArkSignups_Match_Governor');

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = N'FK_ArkSignups_MatchId'
          AND parent_object_id = OBJECT_ID(N'[dbo].[ArkSignups]')
    )
        INSERT INTO @Errors VALUES (N'Missing FK: FK_ArkSignups_MatchId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = N'FK_ArkAuditLog_MatchId'
          AND parent_object_id = OBJECT_ID(N'[dbo].[ArkAuditLog]')
    )
        INSERT INTO @Errors VALUES (N'Missing FK: FK_ArkAuditLog_MatchId');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkMatches]')
          AND name = N'IX_ArkMatches_Open'
    )
        INSERT INTO @Errors VALUES (N'Missing index: IX_ArkMatches_Open');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkSignups]')
          AND name = N'IX_ArkSignups_MatchRoster'
    )
        INSERT INTO @Errors VALUES (N'Missing index: IX_ArkSignups_MatchRoster');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkBans]')
          AND name = N'IX_ArkBans_DiscordUserId_Active'
    )
        INSERT INTO @Errors VALUES (N'Missing index: IX_ArkBans_DiscordUserId_Active');

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'[dbo].[ArkBans]')
          AND name = N'IX_ArkBans_GovernorId_Active'
    )
        INSERT INTO @Errors VALUES (N'Missing index: IX_ArkBans_GovernorId_Active');

    IF EXISTS (SELECT 1 FROM @Errors)
    BEGIN
        SELECT * FROM @Errors;
        RAISERROR (N'Ark schema verification failed. See errors above.', 16, 1);
        RETURN;
    END

    SELECT N'OK' AS [Status], N'Ark schema verification passed.' AS [Message];
END
