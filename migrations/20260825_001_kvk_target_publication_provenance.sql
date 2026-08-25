/*
MigrationId: 20260825_001_kvk_target_publication_provenance
Purpose: Add durable KVK target publication provenance, immutable bot rows, and Official republish protection
Author: cwatts
CreatedUtc: 2026-08-25
RequiresBackup: Yes
RiskLevel: High
Rollback: Manual
RollbackScript: N/A
TransactionMode: Required
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing rows; creates empty publication tables until an operator publishes an explicit KVK
PreValidationQuery: Verify publication objects do not exist, dbo.v_TARGETS_FOR_UPLOAD is not a table, and capture dbo.sp_TARGETS_MASTER definition
PostValidationQuery: Verify new objects, constraints, indexes, view columns, and sp_TARGETS_MASTER force/Official guards; publish and verify the current KVK separately
RelatedBotPR:
RelatedSQLPR:
*/

/*
Deployment and rollback posture:
    - Deploy this SQL migration before the bot code that reads dbo.v_KVK_TARGETS_FOR_BOT.
    - The migration does not publish or backfill any KVK. Current-KVK publication is a separate,
      explicit operator action after schema deployment and validation.
    - Back up the database and capture the current sp_TARGETS_MASTER definition before deployment.
    - Manual rollback restores the captured procedure definition. Retain the additive publication
      tables and their audit history; do not drop committed provenance as an automatic rollback.
    - If deployment fails, roll back the open transaction. If a later publication is incorrect,
      keep the previous current publication and use an approved force-republish or forward fix.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET LOCK_TIMEOUT 60000;

BEGIN TRANSACTION;

DECLARE @MigrationLockResult int;
EXEC @MigrationLockResult = sys.sp_getapplock
    @Resource = N'K98:KVKTargetPublication:Migration',
    @LockMode = N'Exclusive',
    @LockOwner = N'Transaction',
    @LockTimeout = 60000,
    @DbPrincipal = N'public';

IF @MigrationLockResult < 0
    THROW 52650, 'KVK target publication migration could not acquire the migration mutex.', 1;

IF OBJECT_ID(N'dbo.KVK_Target_Publication', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KVK_Target_Publication_Row', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT', N'V') IS NOT NULL
    THROW 52651, 'KVK target publication migration refused a partial or previously applied schema.', 1;

IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', N'U') IS NOT NULL
    THROW 52656, 'KVK target publication migration refused a table named dbo.v_TARGETS_FOR_UPLOAD.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_TARGETS_MASTER', N'P')) LIKE N'%@ForceRepublish%'
    THROW 52657, 'KVK target publication migration refused an already-modified master procedure.', 1;

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.KVK_Target_Publication', N'U') IS NULL
BEGIN
CREATE TABLE dbo.KVK_Target_Publication
(
    PublicationId bigint IDENTITY(1, 1) NOT NULL,
    KVK_NO int NOT NULL,
    PublicationState nvarchar(16) COLLATE Latin1_General_CI_AS NOT NULL,
    SourceScanOrder int NOT NULL,
    SourceScanType nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
    ConfiguredDraftScan int NULL,
    ConfiguredMatchmakingScan int NULL,
    PublishedAtUtc datetime2(3) NOT NULL,
    TargetRowCount int NOT NULL,
    OutputObjectName nvarchar(257) COLLATE Latin1_General_CI_AS NOT NULL,
    PublicationVersion int NOT NULL,
    PublicationSignature uniqueidentifier NOT NULL,
    IsCurrent bit NOT NULL,
    ForcedRepublish bit NOT NULL,
    RepublishReason nvarchar(400) COLLATE Latin1_General_CI_AS NULL,
    PublishedBy nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL,
    CONSTRAINT PK_KVK_Target_Publication
        PRIMARY KEY CLUSTERED (PublicationId),
    CONSTRAINT UQ_KVK_Target_Publication_KVK_Version
        UNIQUE (KVK_NO, PublicationVersion),
    CONSTRAINT UQ_KVK_Target_Publication_Signature
        UNIQUE (PublicationSignature),
    CONSTRAINT CK_KVK_Target_Publication_Values
        CHECK
        (
            KVK_NO > 0
            AND SourceScanOrder > 0
            AND TargetRowCount > 0
            AND PublicationVersion > 0
            AND (ConfiguredDraftScan IS NULL OR ConfiguredDraftScan > 0)
            AND (ConfiguredMatchmakingScan IS NULL OR ConfiguredMatchmakingScan > 0)
        ),
    CONSTRAINT CK_KVK_Target_Publication_StateSource
        CHECK
        (
            (
                PublicationState = N'DRAFT'
                AND SourceScanType = N'DRAFTSCAN'
                AND ConfiguredDraftScan IS NOT NULL
                AND SourceScanOrder <= ConfiguredDraftScan
            )
            OR
            (
                PublicationState = N'OFFICIAL'
                AND SourceScanType = N'MATCHMAKING_SCAN'
                AND ConfiguredMatchmakingScan IS NOT NULL
                AND SourceScanOrder = ConfiguredMatchmakingScan
            )
        ),
    CONSTRAINT CK_KVK_Target_Publication_RepublishAudit
        CHECK
        (
            (ForcedRepublish = 0 AND RepublishReason IS NULL)
            OR
            (ForcedRepublish = 1 AND NULLIF(LTRIM(RTRIM(RepublishReason)), N'') IS NOT NULL)
        ),
    CONSTRAINT CK_KVK_Target_Publication_OutputObject
        CHECK
        (
            OutputObjectName =
                N'dbo.EXCEL_EXPORT_KVK_TARGETS_' + CONVERT(nvarchar(20), KVK_NO)
        )
);

CREATE UNIQUE NONCLUSTERED INDEX UX_KVK_Target_Publication_Current
    ON dbo.KVK_Target_Publication (KVK_NO)
    WHERE IsCurrent = 1;
END

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.KVK_Target_Publication_Row', N'U') IS NULL
BEGIN
CREATE TABLE dbo.KVK_Target_Publication_Row
(
    PublicationId bigint NOT NULL,
    GovernorID bigint NOT NULL,
    TargetRank bigint NULL,
    GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
    Power nvarchar(4000) COLLATE Latin1_General_CI_AS NULL,
    KillTarget int NULL,
    MinimumKillTarget int NULL,
    DeadTarget int NULL,
    DKPTarget int NULL,
    CONSTRAINT PK_KVK_Target_Publication_Row
        PRIMARY KEY CLUSTERED (PublicationId, GovernorID),
    CONSTRAINT FK_KVK_Target_Publication_Row_Publication
        FOREIGN KEY (PublicationId)
        REFERENCES dbo.KVK_Target_Publication (PublicationId),
    CONSTRAINT CK_KVK_Target_Publication_Row_Values
        CHECK
        (
            GovernorID > 0
            AND (KillTarget IS NULL OR KillTarget >= 0)
            AND (MinimumKillTarget IS NULL OR MinimumKillTarget >= 0)
            AND (DeadTarget IS NULL OR DeadTarget >= 0)
            AND (DKPTarget IS NULL OR DKPTarget >= 0)
        )
);
END

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT', N'V') IS NULL
EXECUTE dbo.sp_executesql N'
CREATE VIEW dbo.v_KVK_TARGETS_FOR_BOT
AS
SELECT
    p.PublicationId,
    p.KVK_NO,
    p.PublicationState,
    p.SourceScanOrder,
    p.SourceScanType,
    p.ConfiguredDraftScan,
    p.ConfiguredMatchmakingScan,
    p.PublishedAtUtc,
    p.TargetRowCount,
    p.OutputObjectName,
    p.PublicationVersion,
    p.PublicationSignature,
    r.TargetRank,
    r.GovernorID,
    r.GovernorName,
    r.Power,
    r.KillTarget AS Kill_Target,
    r.MinimumKillTarget AS Min_Kill_Target,
    r.DeadTarget AS Deads_Target,
    r.DKPTarget AS DKP_Target
FROM dbo.KVK_Target_Publication AS p
JOIN dbo.KVK_Target_Publication_Row AS r
  ON r.PublicationId = p.PublicationId
WHERE p.IsCurrent = 1;
'
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]
    @KVK [int] = NULL,
    @ForceRepublish [bit] = 0,
    @RepublishReason [nvarchar](400) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF @@TRANCOUNT <> 0
    BEGIN
        RAISERROR(
            'sp_TARGETS_MASTER must own its publication transaction and cannot run inside an existing transaction.',
            16,
            1
        );
        RETURN;
    END;

    SET XACT_ABORT ON;

    DECLARE @RequestedKVK int = @KVK;

    IF @RequestedKVK IS NOT NULL AND @RequestedKVK <= 0
        THROW 52598, 'sp_TARGETS_MASTER requires a positive @KVK when one is supplied.', 1;

    IF @ForceRepublish IS NULL
        THROW 52599, 'sp_TARGETS_MASTER requires an explicit @ForceRepublish bit value.', 1;

    IF @ForceRepublish = 1 AND @RequestedKVK IS NULL
        THROW 52600, 'sp_TARGETS_MASTER requires an explicit @KVK when @ForceRepublish = 1.', 1;

    IF @ForceRepublish = 1
       AND NULLIF(LTRIM(RTRIM(@RepublishReason)), N'') IS NULL
        THROW 52601, 'sp_TARGETS_MASTER requires @RepublishReason when @ForceRepublish = 1.', 1;

    IF @ForceRepublish = 0 AND @RepublishReason IS NOT NULL
        THROW 52602, 'sp_TARGETS_MASTER accepts @RepublishReason only when @ForceRepublish = 1.', 1;

    IF @ForceRepublish = 1
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.ProcConfig
           WHERE KVKVersion = @RequestedKVK
             AND ConfigKey IN ('MATCHMAKING_SCAN', 'DRAFTSCAN')
       )
        THROW 52619, 'sp_TARGETS_MASTER could not resolve the requested KVK before force-republish processing.', 1;

    SET ANSI_WARNINGS OFF;

    PRINT N'DBG: sp_TARGETS_MASTER start';

    IF @RequestedKVK IS NULL
        PRINT N'MODE: Full refresh (all KVKs)';
    ELSE IF @ForceRepublish = 1
        PRINT CONCAT('MODE: Forced target republish (KVK ', CAST(@RequestedKVK AS nvarchar(20)), ')');
    ELSE
        PRINT CONCAT('MODE: Incremental refresh (KVK ', CAST(@RequestedKVK AS nvarchar(20)), ' only)');

    BEGIN TRY
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        DECLARE @CurrentKVK int;
        DECLARE @MatchedKVKCount int = 0;

        DECLARE kvk_cursor_master CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT KVKVersion
            FROM dbo.ProcConfig
            WHERE ConfigKey IN ('MATCHMAKING_SCAN', 'DRAFTSCAN')
              AND (@RequestedKVK IS NULL OR KVKVersion = @RequestedKVK)
            ORDER BY KVKVersion;

        SET ANSI_WARNINGS ON;
        PRINT N'Calling CREATE_DELTA_TABLES';
        EXEC dbo.CREATE_DELTA_TABLES;
        SET ANSI_WARNINGS OFF;

        OPEN kvk_cursor_master;
        FETCH NEXT FROM kvk_cursor_master INTO @CurrentKVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @CurrentKVK IS NULL OR @CurrentKVK <= 0
                THROW 52620, 'sp_TARGETS_MASTER found a nonpositive configured KVKVersion.', 1;

            SET @MatchedKVKCount += 1;

            BEGIN TRY
                BEGIN TRANSACTION;

                DECLARE @PublicationLockResult int;
                DECLARE @PublicationLockResource nvarchar(255) =
                    N'K98:KVKTargetPublication:' + CONVERT(nvarchar(20), @CurrentKVK);

                EXEC @PublicationLockResult = sys.sp_getapplock
                    @Resource = @PublicationLockResource,
                    @LockMode = N'Exclusive',
                    @LockOwner = N'Transaction',
                    @LockTimeout = 60000,
                    @DbPrincipal = N'public';

                IF @PublicationLockResult < 0
                    THROW 52603, 'sp_TARGETS_MASTER could not acquire the KVK target publication mutex.', 1;

                PRINT CONCAT('Processing KVKVersion: ', CAST(@CurrentKVK AS nvarchar(20)));

                DECLARE @ConfiguredScanRaw float = NULL;
                DECLARE @DraftScanRaw float = NULL;
                DECLARE @ConfiguredScan int = NULL;
                DECLARE @DraftScan int = NULL;
                DECLARE @MaxAvailableScan int = NULL;
                DECLARE @Scan int = NULL;
                DECLARE @SourceScanType nvarchar(32) = NULL;
                DECLARE @PublicationState nvarchar(16) = NULL;
                DECLARE @ShouldProcess bit = 1;

                SELECT @ConfiguredScanRaw = pc.ConfigValue
                FROM dbo.ProcConfig AS pc WITH (HOLDLOCK)
                WHERE pc.KVKVersion = @CurrentKVK
                  AND pc.ConfigKey = 'MATCHMAKING_SCAN';

                SELECT @DraftScanRaw = pc.ConfigValue
                FROM dbo.ProcConfig AS pc WITH (HOLDLOCK)
                WHERE pc.KVKVersion = @CurrentKVK
                  AND pc.ConfigKey = 'DRAFTSCAN';

                SET @ConfiguredScan = TRY_CONVERT(int, @ConfiguredScanRaw);
                SET @DraftScan = TRY_CONVERT(int, @DraftScanRaw);

                IF @ConfiguredScanRaw IS NOT NULL
                   AND
                   (
                       @ConfiguredScan IS NULL
                       OR @ConfiguredScan <= 0
                       OR @ConfiguredScanRaw <> CONVERT(float, @ConfiguredScan)
                   )
                    THROW 52604, 'sp_TARGETS_MASTER found an invalid MATCHMAKING_SCAN configuration.', 1;

                IF @DraftScanRaw IS NOT NULL
                   AND
                   (
                       @DraftScan IS NULL
                       OR @DraftScan <= 0
                       OR @DraftScanRaw <> CONVERT(float, @DraftScan)
                   )
                    THROW 52605, 'sp_TARGETS_MASTER found an invalid DRAFTSCAN configuration.', 1;

                SELECT @MaxAvailableScan = MAX(ScanOrder)
                FROM dbo.KingdomScanData4;

                IF @MaxAvailableScan IS NULL
                BEGIN
                    PRINT CONCAT('WARN: No scan data in KingdomScanData4; skipping KVK ', CAST(@CurrentKVK AS nvarchar(20)));
                    SET @ShouldProcess = 0;
                END
                ELSE IF @ConfiguredScan IS NOT NULL AND @ConfiguredScan <= @MaxAvailableScan
                BEGIN
                    SET @Scan = @ConfiguredScan;
                    SET @SourceScanType = N'MATCHMAKING_SCAN';
                    SET @PublicationState = N'OFFICIAL';
                    PRINT CONCAT('Using MATCHMAKING_SCAN (', CAST(@Scan AS varchar(30)), ') for KVK ', CAST(@CurrentKVK AS nvarchar(20)));
                END
                ELSE IF @DraftScan IS NOT NULL
                BEGIN
                    SET @Scan = CASE WHEN @DraftScan <= @MaxAvailableScan THEN @DraftScan ELSE @MaxAvailableScan END;
                    SET @SourceScanType = N'DRAFTSCAN';
                    SET @PublicationState = N'DRAFT';
                    PRINT CONCAT('Using DRAFTSCAN (', CAST(@DraftScan AS varchar(30)), ' -> applied ', CAST(@Scan AS varchar(30)), ') for KVK ', CAST(@CurrentKVK AS nvarchar(20)));
                END
                ELSE
                BEGIN
                    PRINT CONCAT('WARN: Neither MATCHMAKING_SCAN nor DRAFTSCAN set; skipping KVK ', CAST(@CurrentKVK AS nvarchar(20)));
                    SET @ShouldProcess = 0;
                END;

                IF @ForceRepublish = 1 AND @ShouldProcess = 0
                    THROW 52606, 'sp_TARGETS_MASTER cannot force-republish without an available configured source scan.', 1;

                IF @ShouldProcess = 1
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM dbo.KingdomScanData4
                       WHERE ScanOrder = @Scan
                   )
                    THROW 52607, 'sp_TARGETS_MASTER could not prove rows for the exact selected source scan.', 1;

                DECLARE @CurrentPublicationState nvarchar(16) = NULL;
                DECLARE @CurrentSourceScanOrder int = NULL;
                DECLARE @CurrentConfiguredMatchmakingScan int = NULL;

                SELECT
                    @CurrentPublicationState = p.PublicationState,
                    @CurrentSourceScanOrder = p.SourceScanOrder,
                    @CurrentConfiguredMatchmakingScan = p.ConfiguredMatchmakingScan
                FROM dbo.KVK_Target_Publication AS p WITH (UPDLOCK, HOLDLOCK)
                WHERE p.KVK_NO = @CurrentKVK
                  AND p.IsCurrent = 1;

                IF @ForceRepublish = 1
                   AND ISNULL(@CurrentPublicationState, N'') <> N'OFFICIAL'
                    THROW 52608, 'sp_TARGETS_MASTER permits force-republish only for an existing Official publication.', 1;

                IF @ForceRepublish = 1
                   AND ISNULL(@SourceScanType, N'') <> N'MATCHMAKING_SCAN'
                    THROW 52609, 'sp_TARGETS_MASTER permits force-republish only from the exact configured MATCHMAKING_SCAN.', 1;

                IF @CurrentPublicationState = N'OFFICIAL'
                   AND @ForceRepublish = 0
                   AND
                   (
                       @ConfiguredScan IS NULL
                       OR @CurrentConfiguredMatchmakingScan <> @ConfiguredScan
                       OR @CurrentSourceScanOrder <> @ConfiguredScan
                   )
                    THROW 52610, 'sp_TARGETS_MASTER found MATCHMAKING_SCAN drift for an existing Official publication; operator review is required.', 1;

                IF @ShouldProcess = 1
                   AND @CurrentPublicationState = N'OFFICIAL'
                   AND @ForceRepublish = 0
                BEGIN
                    IF @SourceScanType <> N'MATCHMAKING_SCAN'
                        THROW 52621, 'sp_TARGETS_MASTER could not reselect the Official publication MATCHMAKING_SCAN; operator review is required.', 1;

                    PRINT CONCAT(
                        'Official targets already published for KVK ',
                        CAST(@CurrentKVK AS nvarchar(20)),
                        ' from scan ',
                        CAST(@CurrentSourceScanOrder AS nvarchar(20)),
                        '; target generation and publication are unchanged.'
                    );

                    BEGIN TRY
                        EXEC dbo.sp_ExcelOutput_ByKVK @CurrentKVK, @CurrentSourceScanOrder;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('ERR: sp_ExcelOutput_ByKVK failed while preserving Official targets: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                        THROW;
                    END CATCH;

                    SET @ShouldProcess = 0;
                END;

                IF @ShouldProcess = 1
                BEGIN
                    PRINT CONCAT('Publishing KVK ', CAST(@CurrentKVK AS varchar(20)), ' with SCANORDER = ', CAST(@Scan AS varchar(30)));

                    BEGIN TRY
                        EXEC dbo.sp_Prep_TargetTable @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('ERR: sp_Prep_TargetTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_ExcelOutput_ByKVK @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('ERR: sp_ExcelOutput_ByKVK failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_Prep_ExcelOutputTable @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('ERR: sp_Prep_ExcelOutputTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_Prep_ExcelExportTable @CurrentKVK;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT('ERR: sp_Prep_ExcelExportTable failed: ', ISNULL(ERROR_MESSAGE(), '(no message)'));
                        THROW;
                    END CATCH;

                    DECLARE @ExportTableName sysname =
                        N'EXCEL_EXPORT_KVK_TARGETS_' + CONVERT(nvarchar(20), @CurrentKVK);
                    DECLARE @ExportObjectName nvarchar(257) =
                        N'dbo.' + @ExportTableName;
                    DECLARE @ExportTableQuoted nvarchar(300) =
                        QUOTENAME(N'dbo') + N'.' + QUOTENAME(@ExportTableName);

                    IF OBJECT_ID(@ExportObjectName, N'U') IS NULL
                        THROW 52611, 'sp_TARGETS_MASTER could not find the generated target export object.', 1;

                    DECLARE @TargetRowCount int = NULL;
                    DECLARE @InvalidTargetRowCount int = NULL;
                    DECLARE @CountSql nvarchar(max) = N'
                        SELECT
                            @RowCountOut = COUNT(*),
                            @InvalidCountOut = COALESCE(SUM
                            (
                                CASE
                                    WHEN [Gov_ID] IS NULL
                                      OR TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                                      OR CONVERT(float, TRY_CONVERT(bigint, [Gov_ID])) <> [Gov_ID]
                                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0
                                      OR [Kill Target] < 0
                                      OR [Minimum Kill Target] < 0
                                      OR [Dead Target] < 0
                                      OR [DKP Target] < 0
                                        THEN 1
                                    ELSE 0
                                END
                            ), 0)
                        FROM ' + @ExportTableQuoted + N';';

                    EXEC sys.sp_executesql
                        @CountSql,
                        N'@RowCountOut int OUTPUT, @InvalidCountOut int OUTPUT',
                        @RowCountOut = @TargetRowCount OUTPUT,
                        @InvalidCountOut = @InvalidTargetRowCount OUTPUT;

                    IF ISNULL(@TargetRowCount, 0) <= 0
                        THROW 52612, 'sp_TARGETS_MASTER refused to publish an empty target set.', 1;

                    IF ISNULL(@InvalidTargetRowCount, 0) <> 0
                        THROW 52613, 'sp_TARGETS_MASTER refused target rows with invalid identity or target values.', 1;

                    SET ANSI_WARNINGS ON;
                    SET ANSI_PADDING ON;
                    SET ARITHABORT ON;
                    SET CONCAT_NULL_YIELDS_NULL ON;
                    SET NUMERIC_ROUNDABORT OFF;

                    DECLARE @PublicationVersion int;
                    DECLARE @PublicationSignature uniqueidentifier = NEWID();
                    DECLARE @PublishedAtUtc datetime2(3) = SYSUTCDATETIME();
                    DECLARE @PublishedBy nvarchar(128) =
                        LEFT(COALESCE(ORIGINAL_LOGIN(), SUSER_SNAME(), N'unknown'), 128);

                    SELECT @PublicationVersion = ISNULL(MAX(p.PublicationVersion), 0) + 1
                    FROM dbo.KVK_Target_Publication AS p WITH (UPDLOCK, HOLDLOCK)
                    WHERE p.KVK_NO = @CurrentKVK;

                    INSERT dbo.KVK_Target_Publication
                    (
                        KVK_NO,
                        PublicationState,
                        SourceScanOrder,
                        SourceScanType,
                        ConfiguredDraftScan,
                        ConfiguredMatchmakingScan,
                        PublishedAtUtc,
                        TargetRowCount,
                        OutputObjectName,
                        PublicationVersion,
                        PublicationSignature,
                        IsCurrent,
                        ForcedRepublish,
                        RepublishReason,
                        PublishedBy
                    )
                    VALUES
                    (
                        @CurrentKVK,
                        @PublicationState,
                        @Scan,
                        @SourceScanType,
                        @DraftScan,
                        @ConfiguredScan,
                        @PublishedAtUtc,
                        @TargetRowCount,
                        @ExportObjectName,
                        @PublicationVersion,
                        @PublicationSignature,
                        0,
                        @ForceRepublish,
                        CASE WHEN @ForceRepublish = 1 THEN LTRIM(RTRIM(@RepublishReason)) ELSE NULL END,
                        @PublishedBy
                    );

                    DECLARE @NewPublicationId bigint = SCOPE_IDENTITY();
                    DECLARE @CopySql nvarchar(max) = N'
                        INSERT dbo.KVK_Target_Publication_Row
                        (
                            PublicationId,
                            GovernorID,
                            TargetRank,
                            GovernorName,
                            Power,
                            KillTarget,
                            MinimumKillTarget,
                            DeadTarget,
                            DKPTarget
                        )
                        SELECT
                            @PublicationId,
                            CONVERT(bigint, [Gov_ID]),
                            [Rank],
                            [Governor_Name],
                            [Power],
                            [Kill Target],
                            [Minimum Kill Target],
                            [Dead Target],
                            [DKP Target]
                        FROM ' + @ExportTableQuoted + N';';

                    EXEC sys.sp_executesql
                        @CopySql,
                        N'@PublicationId bigint',
                        @PublicationId = @NewPublicationId;

                    IF
                    (
                        SELECT COUNT(*)
                        FROM dbo.KVK_Target_Publication_Row
                        WHERE PublicationId = @NewPublicationId
                    ) <> @TargetRowCount
                        THROW 52614, 'sp_TARGETS_MASTER target snapshot row count did not match the generated output.', 1;

                    UPDATE dbo.KVK_Target_Publication
                    SET IsCurrent = 0
                    WHERE KVK_NO = @CurrentKVK
                      AND IsCurrent = 1;

                    UPDATE dbo.KVK_Target_Publication
                    SET IsCurrent = 1
                    WHERE PublicationId = @NewPublicationId;

                    IF @@ROWCOUNT <> 1
                        THROW 52615, 'sp_TARGETS_MASTER could not make exactly one target publication current.', 1;

                    IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', N'U') IS NOT NULL
                        THROW 52616, 'sp_TARGETS_MASTER refused to replace a table named dbo.v_TARGETS_FOR_UPLOAD.', 1;

                    DECLARE @LegacyViewSql nvarchar(max) =
                        N'CREATE OR ALTER VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT * FROM '
                        + @ExportTableQuoted
                        + N';';

                    EXEC sys.sp_executesql @LegacyViewSql;

                    IF
                    (
                        SELECT COUNT(*)
                        FROM dbo.v_KVK_TARGETS_FOR_BOT
                        WHERE KVK_NO = @CurrentKVK
                          AND PublicationId = @NewPublicationId
                          AND PublicationVersion = @PublicationVersion
                          AND PublicationSignature = @PublicationSignature
                    ) <> @TargetRowCount
                        THROW 52617, 'sp_TARGETS_MASTER bot-facing publication view failed post-publication validation.', 1;

                    PRINT CONCAT(
                        'Published ',
                        @PublicationState,
                        ' targets for KVK ',
                        CAST(@CurrentKVK AS nvarchar(20)),
                        ' from ',
                        @SourceScanType,
                        ' scan ',
                        CAST(@Scan AS nvarchar(20)),
                        ' as publication version ',
                        CAST(@PublicationVersion AS nvarchar(20)),
                        ' with ',
                        CAST(@TargetRowCount AS nvarchar(20)),
                        ' rows.'
                    );
                END;

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;

                THROW;
            END CATCH;

            FETCH NEXT FROM kvk_cursor_master INTO @CurrentKVK;
        END;

        IF @ForceRepublish = 1 AND @MatchedKVKCount <> 1
            THROW 52618, 'sp_TARGETS_MASTER could not resolve exactly one configured KVK for force-republish.', 1;

        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        SET ANSI_WARNINGS ON;
        PRINT N'DBG: sp_TARGETS_MASTER complete';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('global', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('global', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS('local', 'kvk_cursor_master') >= -1
        BEGIN
            IF CURSOR_STATUS('local', 'kvk_cursor_master') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        SET ANSI_WARNINGS ON;

        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrProc sysname = ERROR_PROCEDURE();
        DECLARE @ErrLine int = ERROR_LINE();

        PRINT CONCAT(
            N'ERROR in sp_TARGETS_MASTER: ',
            ISNULL(@ErrProc, N'(no procedure)'),
            N' line ',
            CAST(ISNULL(@ErrLine, 0) AS nvarchar(10)),
            N': ',
            ISNULL(@ErrMsg, N'(no message)')
        );

        THROW;
    END CATCH;
END

GO

IF OBJECT_ID(N'dbo.KVK_Target_Publication', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KVK_Target_Publication_Row', N'U') IS NULL
   OR OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT', N'V') IS NULL
   OR OBJECT_ID(N'dbo.sp_TARGETS_MASTER', N'P') IS NULL
    THROW 52652, 'KVK target publication migration post-validation found a missing object.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.KVK_Target_Publication')
      AND name = N'UX_KVK_Target_Publication_Current'
      AND is_unique = 1
      AND has_filter = 1
)
    THROW 52653, 'KVK target publication migration post-validation found a missing current-publication index.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.check_constraints
    WHERE name IN
    (
        N'CK_KVK_Target_Publication_Values',
        N'CK_KVK_Target_Publication_StateSource',
        N'CK_KVK_Target_Publication_RepublishAudit',
        N'CK_KVK_Target_Publication_OutputObject',
        N'CK_KVK_Target_Publication_Row_Values'
    )
      AND is_disabled = 0
      AND is_not_trusted = 0
) <> 5
    THROW 52658, 'KVK target publication migration post-validation found missing or untrusted check constraints.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE parent_object_id = OBJECT_ID(N'dbo.KVK_Target_Publication_Row')
      AND referenced_object_id = OBJECT_ID(N'dbo.KVK_Target_Publication')
      AND name = N'FK_KVK_Target_Publication_Row_Publication'
      AND is_disabled = 0
      AND is_not_trusted = 0
)
    THROW 52659, 'KVK target publication migration post-validation found a missing or untrusted row foreign key.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.KVK_Target_Publication_Row')
      AND name IN (N'KillTarget', N'MinimumKillTarget', N'DeadTarget', N'DKPTarget')
      AND is_nullable = 1
) <> 4
    THROW 52661, 'KVK target publication migration post-validation found non-nullable target amount columns.', 1;

IF
(
    SELECT COUNT(*)
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT')
) <> 20
   OR EXISTS
   (
       SELECT required.ColumnName
       FROM
       (
           VALUES
               (N'PublicationId'),
               (N'KVK_NO'),
               (N'PublicationState'),
               (N'SourceScanOrder'),
               (N'SourceScanType'),
               (N'ConfiguredDraftScan'),
               (N'ConfiguredMatchmakingScan'),
               (N'PublishedAtUtc'),
               (N'TargetRowCount'),
               (N'OutputObjectName'),
               (N'PublicationVersion'),
               (N'PublicationSignature'),
               (N'TargetRank'),
               (N'GovernorID'),
               (N'GovernorName'),
               (N'Power'),
               (N'Kill_Target'),
               (N'Min_Kill_Target'),
               (N'Deads_Target'),
               (N'DKP_Target')
       ) AS required(ColumnName)
       WHERE NOT EXISTS
       (
           SELECT 1
           FROM sys.columns AS actual
           WHERE actual.object_id = OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT')
             AND actual.name = required.ColumnName
       )
   )
    THROW 52660, 'KVK target publication migration post-validation found an unexpected bot-view shape.', 1;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.sp_TARGETS_MASTER')
      AND name = N'@ForceRepublish'
)
   OR NOT EXISTS
(
    SELECT 1
    FROM sys.parameters
    WHERE object_id = OBJECT_ID(N'dbo.sp_TARGETS_MASTER')
      AND name = N'@RepublishReason'
)
    THROW 52654, 'KVK target publication migration post-validation found an incomplete force-republish contract.', 1;

IF OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_TARGETS_MASTER', N'P')) NOT LIKE N'%Official targets already published%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_TARGETS_MASTER', N'P')) NOT LIKE N'%SourceScanType%'
   OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.v_KVK_TARGETS_FOR_BOT', N'V')) NOT LIKE N'%PublicationSignature%'
    THROW 52655, 'KVK target publication migration post-validation found definition drift.', 1;

EXEC sys.sp_refreshsqlmodule N'dbo.v_KVK_TARGETS_FOR_BOT';
EXEC sys.sp_refreshsqlmodule N'dbo.sp_TARGETS_MASTER';

COMMIT TRANSACTION;
GO
