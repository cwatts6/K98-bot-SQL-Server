/*
Purpose:
    Read-only Phase 3 preflight for the approved Phase 2 representative copy.

Safety:
    - Refuses production ROK_TRACKER.
    - Refuses any database other than the named representative copy.
    - Makes no schema or data changes.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ExpectedDatabase sysname =
    N'ROK_TRACKER_BACKUP_TEST_KS4_PHASE3_REHEARSAL';

IF DB_NAME() = N'ROK_TRACKER'
    THROW 51970, 'Phase 3 preflight refuses production ROK_TRACKER.', 1;

IF DB_NAME() <> @ExpectedDatabase
BEGIN
    DECLARE @WrongDatabaseMessage nvarchar(2048) =
        CONCAT(
            N'Phase 3 preflight expected ',
            QUOTENAME(@ExpectedDatabase),
            N' but is connected to ',
            QUOTENAME(DB_NAME()),
            N'.'
        );
    THROW 51971, @WrongDatabaseMessage, 1;
END;

IF @@TRANCOUNT <> 0
    THROW 51972, 'Phase 3 preflight requires no existing user transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM
    (
        VALUES
            (OBJECT_ID(N'dbo.KingdomScanData4'), N'GovernorID', TYPE_ID(N'bigint')),
            (OBJECT_ID(N'dbo.KingdomScanData4'), N'SCANORDER', TYPE_ID(N'int')),
            (OBJECT_ID(N'dbo.KingdomScanData5'), N'GovernorID', TYPE_ID(N'bigint')),
            (OBJECT_ID(N'dbo.KingdomScanData5'), N'SCANORDER', TYPE_ID(N'int')),
            (OBJECT_ID(N'dbo.IMPORT_STAGING'), N'Governor ID', TYPE_ID(N'bigint')),
            (OBJECT_ID(N'dbo.IMPORT_STAGING'), N'SCANORDER', TYPE_ID(N'int'))
    ) AS expected(object_id, column_name, type_id)
    LEFT JOIN sys.columns AS actual
      ON actual.object_id = expected.object_id
     AND actual.name = expected.column_name
     AND actual.system_type_id = expected.type_id
     AND actual.user_type_id = expected.type_id
    WHERE actual.column_id IS NULL
)
BEGIN
    THROW 51973,
        'Phase 3 preflight requires the approved Phase 2 bigint/int source contracts.',
        1;
END;

DECLARE @InvalidPlayerScanMetaRows bigint =
(
    SELECT COUNT_BIG(*)
    FROM dbo.PlayerScanMeta
    WHERE GovernorID <> FLOOR(GovernorID)
       OR GovernorID < -9223372036854775808.0
       OR GovernorID > 9223372036854775807.0
       OR
       (
           FirstScanOrder IS NOT NULL
           AND
           (
               FirstScanOrder <> FLOOR(FirstScanOrder)
               OR FirstScanOrder < -2147483648.0
               OR FirstScanOrder > 2147483647.0
           )
       )
       OR
       (
           LastScanOrder IS NOT NULL
           AND
           (
               LastScanOrder <> FLOOR(LastScanOrder)
               OR LastScanOrder < -2147483648.0
               OR LastScanOrder > 2147483647.0
           )
       )
);

DECLARE @InvalidSummaryStateRows bigint =
(
    SELECT COUNT_BIG(*)
    FROM dbo.SUMMARY_PROC_STATE
    WHERE LastScanOrder IS NOT NULL
      AND
      (
          LastScanOrder <> FLOOR(LastScanOrder)
          OR LastScanOrder < -2147483648.0
          OR LastScanOrder > 2147483647.0
      )
);

DECLARE @InvalidStagingStatsRows bigint =
(
    SELECT COUNT_BIG(*)
    FROM dbo.STAGING_STATS
    WHERE GovernorID <> FLOOR(GovernorID)
       OR GovernorID < -9223372036854775808.0
       OR GovernorID > 9223372036854775807.0
       OR PowerRank <> FLOOR(PowerRank)
       OR PowerRank < -2147483648.0
       OR PowerRank > 2147483647.0
);

IF @InvalidPlayerScanMetaRows <> 0
   OR @InvalidSummaryStateRows <> 0
   OR @InvalidStagingStatsRows <> 0
BEGIN
    THROW 51974,
        'Phase 3 preflight found a non-integral or out-of-range downstream value.',
        1;
END;

SELECT
    N'phase3_preflight' AS EvidenceSection,
    DB_NAME() AS DatabaseName,
    (SELECT COUNT_BIG(*) FROM dbo.PlayerScanMeta)
        AS PlayerScanMetaRows,
    (SELECT COUNT_BIG(*) FROM dbo.SUMMARY_PROC_STATE)
        AS SummaryStateRows,
    (SELECT COUNT_BIG(*) FROM dbo.STAGING_STATS)
        AS StagingStatsRows,
    @InvalidPlayerScanMetaRows AS InvalidPlayerScanMetaRows,
    @InvalidSummaryStateRows AS InvalidSummaryStateRows,
    @InvalidStagingStatsRows AS InvalidStagingStatsRows,
    OBJECT_ID(N'dbo.KS4_ImportFileReceipt', N'U')
        AS ExistingReceiptObjectId,
    XACT_STATE() AS XactState,
    @@TRANCOUNT AS TranCount,
    N'PASS' AS PreflightStatus;
