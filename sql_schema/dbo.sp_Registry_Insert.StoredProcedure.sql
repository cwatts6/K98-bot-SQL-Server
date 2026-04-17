SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Registry_Insert]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Registry_Insert] AS' 
END
ALTER PROCEDURE [dbo].[sp_Registry_Insert]
	@DiscordUserID [bigint],
	@DiscordName [nvarchar](200) = NULL,
	@GovernorID [bigint],
	@GovernorName [nvarchar](200) = NULL,
	@AccountType [nvarchar](20),
	@CreatedByDiscordID [bigint] = NULL,
	@Provenance [nvarchar](20) = 'bot_command',
	@NewRegistrationID [bigint] OUTPUT,
	@ResultCode [int] OUTPUT,
	@ResultMessage [nvarchar](500) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NewRegistrationID = NULL;
    SET @ResultCode        = 9;
    SET @ResultMessage     = 'Unexpected error';

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Guard: check for duplicate active slot
        IF EXISTS (
            SELECT 1
            FROM   [dbo].[DiscordGovernorRegistry]
            WHERE  [DiscordUserID]      = @DiscordUserID
              AND  [AccountType]        = @AccountType
              AND  [RegistrationStatus] = 'Active'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @ResultCode    = 1;
            SET @ResultMessage = CONCAT(
                'DiscordUserID ', @DiscordUserID,
                ' already has an active registration in slot ', @AccountType, '.'
            );
            RETURN;
        END

        -- Guard: check for duplicate active governor
        IF EXISTS (
            SELECT 1
            FROM   [dbo].[DiscordGovernorRegistry]
            WHERE  [GovernorID]         = @GovernorID
              AND  [RegistrationStatus] = 'Active'
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @ResultCode    = 2;
            SET @ResultMessage = CONCAT(
                'GovernorID ', @GovernorID,
                ' is already actively registered by another Discord user.'
            );
            RETURN;
        END

        INSERT INTO [dbo].[DiscordGovernorRegistry]
            ([DiscordUserID],[DiscordName],[GovernorID],[GovernorName],
             [AccountType],[RegistrationStatus],
             [CreatedAtUTC],[UpdatedAtUTC],
             [CreatedByDiscordID],[UpdatedByDiscordID],[Provenance])
        VALUES
            (@DiscordUserID, @DiscordName, @GovernorID, @GovernorName,
             @AccountType, 'Active',
             SYSUTCDATETIME(), SYSUTCDATETIME(),
             @CreatedByDiscordID, @CreatedByDiscordID, @Provenance);

        SET @NewRegistrationID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        SET @ResultCode    = 0;
        SET @ResultMessage = CONCAT(
            'Registered GovernorID ', @GovernorID,
            ' for DiscordUserID ', @DiscordUserID,
            ' in slot ', @AccountType, '.'
        );
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultCode    = 9;
        SET @ResultMessage = CONCAT(
            'Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE()
        );
    END CATCH
END

