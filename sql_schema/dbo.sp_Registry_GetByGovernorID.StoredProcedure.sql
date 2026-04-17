SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Registry_GetByGovernorID]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Registry_GetByGovernorID] AS' 
END
ALTER PROCEDURE [dbo].[sp_Registry_GetByGovernorID]
	@GovernorID [bigint],
	@StatusFilter [nvarchar](10) = 'Active'
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
    WHERE [GovernorID] = @GovernorID
      AND (
            @StatusFilter = 'All'
            OR [RegistrationStatus] = @StatusFilter
          );
END

