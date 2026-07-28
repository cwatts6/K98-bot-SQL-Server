/*
Run in a second SSMS connection while 03_lock_session_a.sql holds the mutex.
Expected lock-helper result is -1 (immediate timeout), followed by no leak.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF DB_NAME() = N'ROK_TRACKER'
    THROW 51994, 'Phase 3 lock rehearsal refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL'
    THROW 51995, 'Phase 3 lock rehearsal session B is connected to the wrong database.', 1;

IF @@TRANCOUNT <> 0
    THROW 51996, 'Phase 3 lock rehearsal session B requires no existing transaction.', 1;

DECLARE @LockResult int;

BEGIN TRANSACTION;

EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
    @LockTimeout = 0,
    @LockResult = @LockResult OUTPUT;

DECLARE @ObservedXactState int = XACT_STATE();
DECLARE @ObservedTranCount int = @@TRANCOUNT;

ROLLBACK TRANSACTION;

IF @LockResult <> -1
    THROW 51997, 'Phase 3 lock rehearsal session B did not observe the expected mutex timeout.', 1;

IF XACT_STATE() <> 0 OR @@TRANCOUNT <> 0
    THROW 51998, 'Phase 3 lock rehearsal session B leaked a transaction.', 1;

SELECT
    N'phase3_lock_session_b' AS EvidenceSection,
    @@SPID AS SessionId,
    @LockResult AS LockResult,
    @ObservedXactState AS ObservedXactState,
    @ObservedTranCount AS ObservedTranCount,
    XACT_STATE() AS FinalXactState,
    @@TRANCOUNT AS FinalTranCount,
    N'PASS' AS RehearsalStatus;
