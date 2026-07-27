USE [ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL];
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 52110, 'Concurrent UPDATE_ALL2 session B is restricted to the named representative database.', 1;

DECLARE
    @StartedAtUtc datetime2(3) = SYSUTCDATETIME(),
    @CompletedAtUtc datetime2(3),
    @CaughtErrorNumber int = NULL,
    @CaughtErrorMessage nvarchar(4000) = NULL;

BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SELECT
        @CaughtErrorNumber = ERROR_NUMBER(),
        @CaughtErrorMessage = ERROR_MESSAGE();
END CATCH;

SET @CompletedAtUtc = SYSUTCDATETIME();

SELECT
    N'phase3_concurrent_update_all2_b' AS EvidenceSection,
    @@SPID AS SessionId,
    @StartedAtUtc AS StartedAtUtc,
    @CompletedAtUtc AS CompletedAtUtc,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, @CompletedAtUtc) AS DurationMs,
    @CaughtErrorNumber AS CaughtErrorNumber,
    @CaughtErrorMessage AS CaughtErrorMessage,
    @@TRANCOUNT AS FinalTranCount,
    CASE WHEN @CaughtErrorNumber IS NULL THEN N'winner' ELSE N'loser' END AS SessionOutcome;
