SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_Registry_SoftDelete]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_Registry_SoftDelete] AS' 
END
ALTER PROCEDURE [dbo].[sp_Registry_SoftDelete]
	@RegistrationID [bigint] = NULL,
	@DiscordUserID [bigint] = NULL,
	@AccountType [nvarchar](20) = NULL,
	@UpdatedByDiscordID [bigint] = NULL,
	@NewStatus [nvarchar](20) = 'Removed',
	@ResultCode [int] OUTPUT,
	@ResultMessage [nvarchar](500) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ResultCode    = 9;
    SET @ResultMessage = 'Unexpected error';

    IF @NewStatus NOT IN ('Removed','Superseded')
    BEGIN
        SET @ResultCode    = 9;
        SET @ResultMessage = 'Invalid @NewStatus. Must be Removed or Superseded.';
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE [dbo].[DiscordGovernorRegistry]
        SET
            [RegistrationStatus] = @NewStatus,
            [UpdatedAtUTC]       = SYSUTCDATETIME(),
            [UpdatedByDiscordID] = @UpdatedByDiscordID
        WHERE [RegistrationStatus] = 'Active'
          AND (
                (@RegistrationID IS NOT NULL AND [RegistrationID] = @RegistrationID)
                OR
                (@DiscordUserID  IS NOT NULL AND [DiscordUserID]  = @DiscordUserID
                 AND @AccountType IS NOT NULL AND [AccountType]   = @AccountType)
              );

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @ResultCode    = 3;
            SET @ResultMessage = 'No active registration found matching the supplied criteria.';
            RETURN;
        END

        COMMIT TRANSACTION;
        SET @ResultCode    = 0;
        SET @ResultMessage = CONCAT('Registration marked as ', @NewStatus, '.');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SET @ResultCode    = 9;
        SET @ResultMessage = CONCAT('Error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
    END CATCH
END

