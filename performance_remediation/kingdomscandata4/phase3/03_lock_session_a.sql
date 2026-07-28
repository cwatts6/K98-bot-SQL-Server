/*
Run in SSMS session A on the representative copy only.
This deliberately leaves one transaction open until the cleanup block is run.
Run 04_lock_session_b.sql in a second SSMS connection before cleanup.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 51990, 'Phase 3 lock rehearsal refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 51991, 'Phase 3 lock rehearsal session A is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 51992, 'Phase 3 lock rehearsal session A requires no existing transaction.', 1;

DECLARE @LockResult int;

BEGIN TRANSACTION;

EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 0,
    @LockResult = @LockResult OUTPUT;

IF @LockResult < 0
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51993, 'Phase 3 lock rehearsal session A could not acquire the mutex.', 1;
END;

SELECT
    N'phase3_lock_session_a_held' AS EvidenceSection,
    @@SPID AS SessionId,
    @LockResult AS LockResult,
    XACT_STATE() AS XactState,
    @@TRANCOUNT AS TranCount,
    N'Run 04_lock_session_b.sql now; then run the cleanup block below.'
        AS NextStep;

/*
Cleanup after session B reports PASS:

IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;

SELECT
    @@SPID AS SessionId,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount;
*/
