SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Registry_GetAllActive]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Registry_GetAllActive] AS' 
END
ALTER PROCEDURE [dbo].[sp_Registry_GetAllActive]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        [RegistrationID],
        [DiscordUserID],
        [DiscordName],
        [GovernorID],
        [GovernorName],
        [AccountType],
        [RegistrationStatus],
        [CreatedAtUTC],
        [UpdatedAtUTC],
        [CreatedByDiscordID],
        [UpdatedByDiscordID],
        [Provenance]
    FROM  [dbo].[DiscordGovernorRegistry]
    WHERE [RegistrationStatus] = 'Active'
    ORDER BY
        [DiscordUserID],
        CASE
            WHEN [AccountType] = 'Main'    THEN 0
            WHEN [AccountType] LIKE 'Alt%' THEN 1
            WHEN [AccountType] LIKE 'Farm%'THEN 2
            ELSE 9
        END,
        TRY_CAST(
            NULLIF(LTRIM(REPLACE(REPLACE([AccountType], 'Alt ', ''), 'Farm ', '')), '')
            AS INT
        ) ASC;
END

