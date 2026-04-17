SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Registry_UpsertFromImport]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Registry_UpsertFromImport] AS' 
END
ALTER PROCEDURE [dbo].[sp_Registry_UpsertFromImport]
	@DiscordUserID [bigint],
	@DiscordName [nvarchar](200) = NULL,
	@GovernorID [bigint],
	@GovernorName [nvarchar](200) = NULL,
	@AccountType [nvarchar](20),
	@ActorDiscordID [bigint] = NULL,
	@Provenance [nvarchar](20) = 'import',
	@ConflictBehaviour [nvarchar](20) = 'Skip',
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

        -- Check for duplicate active governor owned by a DIFFERENT Discord user
        IF EXISTS (
            SELECT 1
            FROM   [dbo].[DiscordGovernorRegistry]
            WHERE  [GovernorID]         = @GovernorID
              AND  [RegistrationStatus] = 'Active'
              AND  [DiscordUserID]     <> @DiscordUserID
        )
        BEGIN
            ROLLBACK TRANSACTION;
            SET @ResultCode    = 2;
            SET @ResultMessage = CONCAT(
                'GovernorID ', @GovernorID,
                ' is already actively registered by a different Discord user.'
            );
            RETURN;
        END

        -- Check for existing active slot for this user
        DECLARE @ExistingID BIGINT = NULL;
        SELECT @ExistingID = [RegistrationID]
        FROM   [dbo].[DiscordGovernorRegistry]
        WHERE  [DiscordUserID]      = @DiscordUserID
          AND  [AccountType]        = @AccountType
          AND  [RegistrationStatus] = 'Active';

        IF @ExistingID IS NOT NULL
        BEGIN
            IF @ConflictBehaviour = 'Skip'
            BEGIN
                ROLLBACK TRANSACTION;
                SET @ResultCode    = 4;
                SET @ResultMessage = CONCAT(
                    'Skipped: DiscordUserID ', @DiscordUserID,
                    ' slot ', @AccountType, ' already has an active registration.'
                );
                RETURN;
            END

            -- Overwrite: soft-delete existing row
            UPDATE [dbo].[DiscordGovernorRegistry]
            SET
                [RegistrationStatus] = 'Superseded',
                [UpdatedAtUTC]       = SYSUTCDATETIME(),
                [UpdatedByDiscordID] = @ActorDiscordID
            WHERE [RegistrationID] = @ExistingID;
        END

        -- Insert new row
        INSERT INTO [dbo].[DiscordGovernorRegistry]
            ([DiscordUserID],[DiscordName],[GovernorID],[GovernorName],
             [AccountType],[RegistrationStatus],
             [CreatedAtUTC],[UpdatedAtUTC],
             [CreatedByDiscordID],[UpdatedByDiscordID],[Provenance])
        VALUES
            (@DiscordUserID, @DiscordName, @GovernorID, @GovernorName,
             @AccountType, 'Active',
             SYSUTCDATETIME(), SYSUTCDATETIME(),
             @ActorDiscordID, @ActorDiscordID, @Provenance);

        SET @NewRegistrationID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        IF @ExistingID IS NOT NULL
        BEGIN
            SET @ResultCode    = 5;
            SET @ResultMessage = CONCAT(
                'Overwritten: RegistrationID ', @ExistingID,
                ' superseded; new RegistrationID ', @NewRegistrationID, '.'
            );
        END
        ELSE
        BEGIN
            SET @ResultCode    = 0;
            SET @ResultMessage = CONCAT(
                'Inserted: RegistrationID ', @NewRegistrationID,
                ' for DiscordUserID ', @DiscordUserID,
                ' slot ', @AccountType, '.'
            );
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultCode    = 9;
        SET @ResultMessage = CONCAT('Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
    END CATCH
END

