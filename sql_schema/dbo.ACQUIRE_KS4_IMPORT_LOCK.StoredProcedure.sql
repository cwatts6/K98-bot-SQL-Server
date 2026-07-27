SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[ACQUIRE_KS4_IMPORT_LOCK]
    @LockTimeout [int] = 60000,
    @LockResult [int] OUTPUT
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT = 0
        THROW 51870, 'ACQUIRE_KS4_IMPORT_LOCK requires an active caller transaction.', 1;

    IF @LockTimeout < 0 OR @LockTimeout > 60000
        THROW 51871, 'ACQUIRE_KS4_IMPORT_LOCK requires a timeout from 0 through 60000 ms.', 1;

    EXEC @LockResult = sys.sp_getapplock
        @Resource = N'K98:KingdomScanData4:ImportPipeline:v1',
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = @LockTimeout,
        @DbPrincipal = N'K98ImportLockPrincipal';
END
GO
