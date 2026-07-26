SET NOCOUNT ON;
SET XACT_ABORT ON;

USE [ROK_TRACKER_BACKUP_TEST_KS4];

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4';
DECLARE @RunId uniqueidentifier;
DECLARE @SessionLabel nchar(1);
DECLARE @ClaimOrdinal int;
DECLARE @StartAtUtc datetime2(7);
DECLARE @ReadyDeadlineUtc datetime2(7) =
    DATEADD(minute, 5, SYSUTCDATETIME());
DECLARE @StartedAtUtc datetime2(7);
DECLARE @CompletedAtUtc datetime2(7);
DECLARE @ErrorNumber int = NULL;
DECLARE @ErrorMessage nvarchar(4000) = NULL;
DECLARE @TransactionCountAfterCall int;
DECLARE @XactStateAfterCall int;
DECLARE @TransactionCountAfterCleanup int;

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    THROW 51094,
        'Refusing to run concurrency outside the guarded rehearsal database.',
        1;
END;

IF @@TRANCOUNT <> 0
BEGIN
    THROW 51094,
        'The concurrency runner requires a session with no open transaction.',
        1;
END;

SELECT @RunId = RunId
FROM dbo.K98_UpdateAll2ConcurrencyControl
WHERE ControlId = 1;

IF @RunId IS NULL
BEGIN
    THROW 51094,
        'Concurrency preparation has not been completed.',
        1;
END;

BEGIN TRANSACTION;

SELECT @ClaimOrdinal = COUNT(*)
FROM dbo.K98_UpdateAll2ConcurrencyReady
    WITH (TABLOCKX, HOLDLOCK)
WHERE RunId = @RunId;

IF @ClaimOrdinal >= 2
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51094,
        'Both concurrency session labels have already been claimed.',
        1;
END;

SET @SessionLabel =
    CASE @ClaimOrdinal
        WHEN 0 THEN N'A'
        WHEN 1 THEN N'B'
    END;

INSERT INTO dbo.K98_UpdateAll2ConcurrencyReady
(
    RunId,
    SessionLabel,
    SessionId,
    ReadyAtUtc
)
VALUES
(
    @RunId,
    @SessionLabel,
    @@SPID,
    SYSUTCDATETIME()
);

COMMIT TRANSACTION;

WHILE @StartAtUtc IS NULL
BEGIN
    UPDATE dbo.K98_UpdateAll2ConcurrencyControl
    SET StartAtUtc = DATEADD(second, 5, SYSUTCDATETIME())
    WHERE ControlId = 1
      AND RunId = @RunId
      AND StartAtUtc IS NULL
      AND (
          SELECT COUNT(*)
          FROM dbo.K98_UpdateAll2ConcurrencyReady
          WHERE RunId = @RunId
      ) = 2;

    SELECT @StartAtUtc = StartAtUtc
    FROM dbo.K98_UpdateAll2ConcurrencyControl
    WHERE ControlId = 1
      AND RunId = @RunId;

    IF @StartAtUtc IS NULL
    BEGIN
        IF SYSUTCDATETIME() >= @ReadyDeadlineUtc
        BEGIN
            THROW 51094,
                'Timed out waiting for the second concurrency session.',
                1;
        END;

        WAITFOR DELAY '00:00:00.100';
    END;
END;

WHILE SYSUTCDATETIME() < @StartAtUtc
BEGIN
    WAITFOR DELAY '00:00:00.020';
END;

SET @StartedAtUtc = SYSUTCDATETIME();

BEGIN TRY
    EXEC dbo.UPDATE_ALL2;
END TRY
BEGIN CATCH
    SET @ErrorNumber = ERROR_NUMBER();
    SET @ErrorMessage = ERROR_MESSAGE();
END CATCH;

SET @CompletedAtUtc = SYSUTCDATETIME();
SET @TransactionCountAfterCall = @@TRANCOUNT;
SET @XactStateAfterCall = XACT_STATE();

IF @@TRANCOUNT <> 0
BEGIN
    ROLLBACK TRANSACTION;
END;

SET @TransactionCountAfterCleanup = @@TRANCOUNT;

INSERT INTO dbo.K98_UpdateAll2ConcurrencyResult
(
    RunId,
    SessionLabel,
    SessionId,
    StartedAtUtc,
    CompletedAtUtc,
    ElapsedMilliseconds,
    ErrorNumber,
    ErrorMessage,
    TransactionCountAfterCall,
    XactStateAfterCall,
    TransactionCountAfterCleanup
)
VALUES
(
    @RunId,
    @SessionLabel,
    @@SPID,
    @StartedAtUtc,
    @CompletedAtUtc,
    DATEDIFF_BIG(millisecond, @StartedAtUtc, @CompletedAtUtc),
    @ErrorNumber,
    @ErrorMessage,
    @TransactionCountAfterCall,
    @XactStateAfterCall,
    @TransactionCountAfterCleanup
);

SELECT
    N'update_all2_concurrency_session' AS EvidenceSection,
    @RunId AS RunId,
    @SessionLabel AS SessionLabel,
    @@SPID AS SessionId,
    @StartedAtUtc AS StartedAtUtc,
    @CompletedAtUtc AS CompletedAtUtc,
    DATEDIFF_BIG(
        millisecond,
        @StartedAtUtc,
        @CompletedAtUtc
    ) AS ElapsedMilliseconds,
    @ErrorNumber AS ErrorNumber,
    @ErrorMessage AS ErrorMessage,
    @TransactionCountAfterCall AS TransactionCountAfterCall,
    @XactStateAfterCall AS XactStateAfterCall,
    @TransactionCountAfterCleanup AS TransactionCountAfterCleanup;
