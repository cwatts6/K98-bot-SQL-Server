SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Stats_for_Upload]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[SP_Stats_for_Upload] AS'
END
ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @LatestKVK bigint,
        @MaxScan int,
        @KvkEndScanValue float,
        @KvkEndScan int,
        @ExpectedFinalScan int,
        @ProvenFinalScan int,
        @HeaderRowCount int,
        @HeaderRevision int,
        @HeaderState nvarchar(24),
        @FinalizationBasis nvarchar(24),
        @FinalDataAtUtc datetime2(0),
        @CurrentHeaderScan int,
        @CurrentHeaderRowCount int,
        @CurrentHeaderRevision int,
        @CurrentHeaderState nvarchar(24),
        @SourceRowCount bigint = 0,
        @InvalidGovernorRows bigint = 0,
        @DuplicateGovernorGroups bigint = 0,
        @WrongKvkRows bigint = 0,
        @CandidateRowCount bigint = 0,
        @PublishedRowCount bigint = 0,
        @ProvenScanDate datetime2(0),
        @ProvenScanDateMax datetime2(0),
        @ScanDateRowCount bigint = 0,
        @TableName sysname,
        @TableObjectName nvarchar(260),
        @TableNameFull nvarchar(260),
        @sql nvarchar(max),
        @Diagnostic nvarchar(2048),
        @FailureStage nvarchar(64) = N'preflight',
        @ImportLockResult int,
        @LockResult int,
        @InitialTranCount int = @@TRANCOUNT,
        @StartedTransaction bit = 0,
        @SavepointCreated bit = 0;

    BEGIN TRY
        IF @InitialTranCount = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION StatsForUploadPublishSave;
            SET @SavepointCreated = 1;
        END;

        SET @FailureStage = N'import-lock';
        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 52820, 'SP_Stats_for_Upload: KS4 import lock could not be acquired.', 1;

        SET @FailureStage = N'publication-lock';
        EXEC @LockResult = sys.sp_getapplock
            @Resource = N'K98:StatsForUpload:Publish',
            @LockMode = N'Exclusive',
            @LockOwner = N'Transaction',
            @LockTimeout = 60000,
            @DbPrincipal = N'public';

        IF @LockResult < 0
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: publication lock failed for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan,
                ', lock result=', @LockResult, '.'
            );
            THROW 52803, @Diagnostic, 1;
        END;

        SET @FailureStage = N'eligibility-snapshot';
        SELECT @MaxScan = MAX(SCANORDER)
        FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK);

        IF @MaxScan IS NULL
            THROW 52800, 'SP_Stats_for_Upload: no scan data is available.', 1;

        SELECT TOP (1) @LatestKVK = KVKVersion
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE ConfigKey = 'MATCHMAKING_SCAN'
          AND TRY_CONVERT(int, ConfigValue) IS NOT NULL
          AND ConfigValue = CONVERT(float, TRY_CONVERT(int, ConfigValue))
          AND TRY_CONVERT(int, ConfigValue) <= @MaxScan
        ORDER BY KVKVersion DESC;

        IF @LatestKVK IS NULL OR @LatestKVK <= 0 OR @LatestKVK > 2147483647
            THROW 52801, 'SP_Stats_for_Upload: no valid eligible KVK was found.', 1;

        SELECT @KvkEndScanValue = ConfigValue
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE KVKVersion = CONVERT(int, @LatestKVK)
          AND ConfigKey = 'KVK_END_SCAN';

        SET @KvkEndScan = TRY_CONVERT(int, @KvkEndScanValue);

        IF @KvkEndScan IS NULL
           OR @KvkEndScan <= 0
           OR @KvkEndScanValue <> CONVERT(float, @KvkEndScan)
            THROW 52802, 'SP_Stats_for_Upload: KVK_END_SCAN is missing or is not a positive integral scan.', 1;

        SET @ExpectedFinalScan = CASE
            WHEN @MaxScan > @KvkEndScan THEN @KvkEndScan
            ELSE @MaxScan
        END;

        SET @FailureStage = N'header-preflight';
        SELECT
            @ProvenFinalScan = FinalScanOrder,
            @HeaderRowCount = OutputRowCount,
            @HeaderRevision = Revision,
            @HeaderState = State,
            @FinalizationBasis = FinalizationBasis,
            @FinalDataAtUtc = FinalDataAtUtc
        FROM dbo.KVKFinalReportHeader
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @ProvenFinalScan IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: missing output header for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan, '.'
            );
            THROW 52804, @Diagnostic, 1;
        END;

        IF @HeaderState <> N'OUTPUT_COMPLETE'
           OR @HeaderRevision IS NULL OR @HeaderRevision <= 0
           OR @HeaderRowCount IS NULL OR @HeaderRowCount <= 0
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: invalid output header for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan,
                ', proven scan=', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), 'NULL'),
                ', revision=', COALESCE(CONVERT(varchar(20), @HeaderRevision), 'NULL'), '.'
            );
            THROW 52805, @Diagnostic, 1;
        END;

        IF @ProvenFinalScan <> @ExpectedFinalScan
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: stale output for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan,
                ', proven scan=', @ProvenFinalScan,
                ', revision=', @HeaderRevision, '.'
            );
            THROW 52806, @Diagnostic, 1;
        END;

        SET @TableName = N'EXCEL_FOR_KVK_' + CONVERT(nvarchar(20), @LatestKVK);
        SET @TableObjectName = N'dbo.' + @TableName;
        SET @TableNameFull = QUOTENAME(N'dbo') + N'.' + QUOTENAME(@TableName);

        IF OBJECT_ID(@TableObjectName, N'U') IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: source object ', @TableObjectName,
                ' is missing for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan, '.'
            );
            THROW 52807, @Diagnostic, 1;
        END;

        SET @FailureStage = N'scan-date';
        SELECT
            @ScanDateRowCount = COUNT_BIG(*),
            @ProvenScanDate = MIN(CONVERT(datetime2(0), ScanDate)),
            @ProvenScanDateMax = MAX(CONVERT(datetime2(0), ScanDate))
        FROM dbo.KingdomScanData4
        WHERE SCANORDER = @ProvenFinalScan;

        IF @ScanDateRowCount <= 0 OR @ProvenScanDate IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: source scan date is missing for KVK=', @LatestKVK,
                ', proven scan=', @ProvenFinalScan, '.'
            );
            THROW 52808, @Diagnostic, 1;
        END;

        IF @ProvenScanDate <> @ProvenScanDateMax
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: source scan date is inconsistent for KVK=', @LatestKVK,
                ', proven scan=', @ProvenFinalScan, '.'
            );
            THROW 52809, @Diagnostic, 1;
        END;

        SET @FailureStage = N'source-shape';
        SET @sql = N'
            SELECT
                @pSourceRowCount = COUNT_BIG(*),
                @pInvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0 THEN 1 ELSE 0 END)), 0),
                @pWrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(int, [KVK_NO]) <> @pLatestKVK
                      OR [KVK_NO] IS NULL THEN 1 ELSE 0 END)), 0)
            FROM ' + @TableNameFull + N' WITH (HOLDLOCK);

            SELECT @pDuplicateGovernorGroups = COUNT_BIG(*)
            FROM
            (
                SELECT TRY_CONVERT(bigint, [Gov_ID]) AS GovernorID
                FROM ' + @TableNameFull + N' WITH (HOLDLOCK)
                GROUP BY TRY_CONVERT(bigint, [Gov_ID])
                HAVING COUNT_BIG(*) > 1
            ) AS duplicates;';

        EXEC sys.sp_executesql
            @sql,
            N'@pLatestKVK int, @pSourceRowCount bigint OUTPUT, @pInvalidGovernorRows bigint OUTPUT, @pWrongKvkRows bigint OUTPUT, @pDuplicateGovernorGroups bigint OUTPUT',
            @pLatestKVK = CONVERT(int, @LatestKVK),
            @pSourceRowCount = @SourceRowCount OUTPUT,
            @pInvalidGovernorRows = @InvalidGovernorRows OUTPUT,
            @pWrongKvkRows = @WrongKvkRows OUTPUT,
            @pDuplicateGovernorGroups = @DuplicateGovernorGroups OUTPUT;

        IF @SourceRowCount <= 0
            THROW 52810, 'SP_Stats_for_Upload: proven source output contains no rows.', 1;

        IF @SourceRowCount <> @HeaderRowCount
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: source/header row-count mismatch for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan,
                ', revision=', @HeaderRevision,
                ', header rows=', @HeaderRowCount,
                ', source rows=', @SourceRowCount, '.'
            );
            THROW 52811, @Diagnostic, 1;
        END;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: invalid source identity for KVK=', @LatestKVK,
                ', invalid governors=', @InvalidGovernorRows,
                ', duplicate governor groups=', @DuplicateGovernorGroups,
                ', wrong KVK rows=', @WrongKvkRows, '.'
            );
            THROW 52812, @Diagnostic, 1;
        END;

        SET @FailureStage = N'candidate-build';
        SELECT TOP (0) *
        INTO #StatsForUploadCandidate
        FROM dbo.STATS_FOR_UPLOAD;

        SET @sql = N'
            INSERT INTO #StatsForUploadCandidate
            (
                [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
                [Starting Power],[Power_Delta],
                [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
                [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],[Conduct],
                [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
                [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
                [Zeroed],[DKP_SCORE],[DKP Target],[% of DKP Target],
                [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
                [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
                [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
                [Starting_HealedTroops],[HealedTroopsDelta],
                [Starting_KillPoints],[KillPointsDelta],
                [RangedPoints],[RangedPointsDelta],[AutarchTimes],
                [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
                [KVK_NO],[LAST_REFRESH],[STATUS]
            )
            SELECT
                [Rank], [KVK_RANK], CAST([Gov_ID] AS bigint), RTRIM([Governor_Name]),
                [Starting Power], ISNULL([Power_Delta], 0),
                [Civilization], ISNULL([KvKPlayed], 0), ISNULL([MostKvKKill], 0),
                ISNULL([MostKvKDead], 0), ISNULL([MostKvKHeal], 0),
                ISNULL([Acclaim], 0), ISNULL([HighestAcclaim], 0), ISNULL([AOOJoined], 0),
                ISNULL([AOOWon], 0), ISNULL([AOOAvgKill], 0), ISNULL([AOOAvgDead], 0),
                ISNULL([AOOAvgHeal], 0), [Conduct],
                ISNULL([Starting_T4&T5_KILLS], 0), ISNULL([T4_KILLS], 0),
                ISNULL([T5_KILLS], 0), ISNULL([T4&T5_Kills], 0), ISNULL([KILLS_OUTSIDE_KVK], 0),
                ISNULL([Kill Target], 0), ISNULL([% of Kill Target], 0),
                ISNULL([Starting_Deads], 0), ISNULL([Deads_Delta], 0),
                ISNULL([DEADS_OUTSIDE_KVK], 0), ISNULL([T4_Deads], 0), ISNULL([T5_Deads], 0),
                ISNULL([Dead_Target], 0), ISNULL([% of Dead Target], 0),
                ISNULL([Zeroed], 0), ISNULL([DKP_SCORE], 0), ISNULL([DKP Target], 0),
                ISNULL([% of DKP Target], 0), ISNULL([HelpsDelta], 0),
                ISNULL([RSS_Assist_Delta], 0), ISNULL([RSS_Gathered_Delta], 0),
                ISNULL([Pass 4 Kills], 0), ISNULL([Pass 6 Kills], 0),
                ISNULL([Pass 7 Kills], 0), ISNULL([Pass 8 Kills], 0),
                ISNULL([Pass 4 Deads], 0), ISNULL([Pass 6 Deads], 0),
                ISNULL([Pass 7 Deads], 0), ISNULL([Pass 8 Deads], 0),
                ISNULL([Starting_HealedTroops], 0), ISNULL([HealedTroopsDelta], 0),
                ISNULL([Starting_KillPoints], 0), ISNULL([KillPointsDelta], 0),
                ISNULL([RangedPoints], 0), ISNULL([RangedPointsDelta], 0), ISNULL([AutarchTimes], 0),
                ISNULL([Max_PreKvk_Points], 0), ISNULL([Max_HonorPoints], 0),
                ISNULL([PreKvk_Rank], 0), ISNULL([Honor_Rank], 0),
                [KVK_NO], @pProvenScanDate,
                CASE
                    WHEN CAST([Gov_ID] AS bigint) IN
                    (
                        SELECT GovernorID
                        FROM dbo.EXEMPT_FROM_STATS
                        WHERE KVK_NO IN (0, @pLatestKVK)
                    ) THEN N''EXEMPT''
                    ELSE N''INCLUDED''
                END
            FROM ' + @TableNameFull + N' WITH (HOLDLOCK);';

        EXEC sys.sp_executesql
            @sql,
            N'@pLatestKVK int, @pProvenScanDate datetime2(0)',
            @pLatestKVK = CONVERT(int, @LatestKVK),
            @pProvenScanDate = @ProvenScanDate;

        SELECT
            @CandidateRowCount = COUNT_BIG(*),
            @InvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN Gov_ID IS NULL OR Gov_ID <= 0 THEN 1 ELSE 0 END)), 0),
            @WrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN KVK_NO <> CONVERT(int, @LatestKVK) OR KVK_NO IS NULL THEN 1 ELSE 0 END)), 0)
        FROM #StatsForUploadCandidate;

        SELECT @DuplicateGovernorGroups = COUNT_BIG(*)
        FROM
        (
            SELECT Gov_ID
            FROM #StatsForUploadCandidate
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        ) AS duplicates;

        IF @CandidateRowCount <= 0 OR @CandidateRowCount <> @SourceRowCount
            THROW 52813, 'SP_Stats_for_Upload: candidate row count does not match the proven source.', 1;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
            THROW 52814, 'SP_Stats_for_Upload: candidate identity validation failed.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #StatsForUploadCandidate
            WHERE LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
            THROW 52815, 'SP_Stats_for_Upload: candidate LAST_REFRESH is not coherent with the proven scan.', 1;

        SET @FailureStage = N'header-recheck';
        SELECT
            @CurrentHeaderScan = FinalScanOrder,
            @CurrentHeaderRowCount = OutputRowCount,
            @CurrentHeaderRevision = Revision,
            @CurrentHeaderState = State
        FROM dbo.KVKFinalReportHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @CurrentHeaderScan IS NULL
           OR @CurrentHeaderRowCount IS NULL
           OR @CurrentHeaderRevision IS NULL
           OR @CurrentHeaderState IS NULL
           OR @CurrentHeaderScan <> @ProvenFinalScan
           OR @CurrentHeaderRowCount <> @HeaderRowCount
           OR @CurrentHeaderRevision <> @HeaderRevision
           OR @CurrentHeaderState <> @HeaderState
        BEGIN
            SET @Diagnostic = CONCAT(
                'SP_Stats_for_Upload: output provenance changed during publication for KVK=', @LatestKVK,
                ', expected scan=', @ExpectedFinalScan,
                ', initial revision=', @HeaderRevision,
                ', current revision=', COALESCE(CONVERT(varchar(20), @CurrentHeaderRevision), 'NULL'), '.'
            );
            THROW 52816, @Diagnostic, 1;
        END;

        SET @FailureStage = N'target-replacement';
        DELETE FROM dbo.STATS_FOR_UPLOAD;

        INSERT INTO dbo.STATS_FOR_UPLOAD
        SELECT *
        FROM #StatsForUploadCandidate;

        SET @PublishedRowCount = @@ROWCOUNT;

        IF @PublishedRowCount <> @CandidateRowCount
            THROW 52817, 'SP_Stats_for_Upload: published row count does not match the validated candidate.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.STATS_FOR_UPLOAD
            WHERE Gov_ID IS NULL OR Gov_ID <= 0
               OR KVK_NO IS NULL OR KVK_NO <> CONVERT(int, @LatestKVK)
               OR LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
        OR EXISTS
        (
            SELECT Gov_ID
            FROM dbo.STATS_FOR_UPLOAD
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        )
            THROW 52818, 'SP_Stats_for_Upload: post-publication row-shape validation failed.', 1;

        SET @FailureStage = N'target-statistics';
        UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;

        PRINT CONCAT(
            'SP_Stats_for_Upload: completed KVK=', @LatestKVK,
            ', expected scan=', @ExpectedFinalScan,
            ', proven scan=', @ProvenFinalScan,
            ', header revision=', @HeaderRevision,
            ', basis=', @FinalizationBasis,
            ', generated at=', CONVERT(varchar(19), @FinalDataAtUtc, 120),
            ', source rows=', @SourceRowCount,
            ', published rows=', @PublishedRowCount,
            ', source scan date=', CONVERT(varchar(19), @ProvenScanDate, 120), '.'
        );
    END TRY
    BEGIN CATCH
        DECLARE @ErrorNumber int = ERROR_NUMBER();
        DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();

        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION StatsForUploadPublishSave;

        IF @ErrorNumber BETWEEN 52800 AND 52820
            THROW;

        SET @Diagnostic = CONCAT(
            'SP_Stats_for_Upload: failed at stage=', @FailureStage,
            ', KVK=', COALESCE(CONVERT(varchar(20), @LatestKVK), 'NULL'),
            ', expected scan=', COALESCE(CONVERT(varchar(20), @ExpectedFinalScan), 'NULL'),
            ', proven scan=', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), 'NULL'),
            ', header revision=', COALESCE(CONVERT(varchar(20), @HeaderRevision), 'NULL'),
            ', source rows=', @SourceRowCount,
            ', published rows=', @PublishedRowCount,
            ', SQL error=', @ErrorNumber,
            ', detail=', LEFT(@ErrorMessage, 600), '.'
        );
        THROW 52819, @Diagnostic, 1;
    END CATCH;
END
