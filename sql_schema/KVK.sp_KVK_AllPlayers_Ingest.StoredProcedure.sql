SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[sp_KVK_AllPlayers_Ingest]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [KVK].[sp_KVK_AllPlayers_Ingest] AS' 
END
ALTER PROCEDURE [KVK].[sp_KVK_AllPlayers_Ingest]
	@IngestToken [uniqueidentifier],
	@ScanTimestampUTC [datetime2](0),
	@SourceFileName [nvarchar](255),
	@FileHash [varbinary](32),
	@UploaderDiscordID [bigint] = NULL,
	@OutKVK_NO [int] OUTPUT,
	@OutScanID [int] OUTPUT,
	@OutRowCount [int] OUTPUT,
	@SchemaVersion [nvarchar](64) = NULL,
	@SourceSheetName [nvarchar](128) = NULL,
	@SourceColumnHash [char](64) = NULL,
	@SourceColumnCount [int] = NULL,
	@SourceRowCount [int] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        IF @IngestToken IS NULL
            THROW 50001, 'IngestToken is required.', 1;
        IF @ScanTimestampUTC IS NULL
            THROW 50002, 'ScanTimestampUTC is required.', 1;
        IF @FileHash IS NULL OR DATALENGTH(@FileHash) = 0
            THROW 50003, 'FileHash is required (use SHA-256).', 1;

        SELECT @OutRowCount = COUNT(*)
        FROM KVK.KVK_AllPlayers_Stage WITH (READCOMMITTEDLOCK)
        WHERE IngestToken = @IngestToken;

        IF @OutRowCount IS NULL OR @OutRowCount = 0
            THROW 50004, 'No staged rows found for IngestToken.', 1;

        SELECT TOP (1)
            @SchemaVersion = COALESCE(@SchemaVersion, s.schema_version),
            @SourceSheetName = COALESCE(@SourceSheetName, s.source_sheet_name),
            @SourceColumnHash = COALESCE(@SourceColumnHash, s.source_column_hash),
            @SourceColumnCount = COALESCE(@SourceColumnCount, s.source_column_count),
            @SourceRowCount = COALESCE(@SourceRowCount, s.source_row_count)
        FROM KVK.KVK_AllPlayers_Stage AS s WITH (READCOMMITTEDLOCK)
        WHERE s.IngestToken = @IngestToken
        ORDER BY s.row_no;

        SET @SourceRowCount = COALESCE(@SourceRowCount, @OutRowCount);

        DECLARE @KVK_NO INT;

        SELECT TOP(1) @KVK_NO = d.KVK_NO
        FROM dbo.KVK_Details AS d WITH (READCOMMITTEDLOCK)
        WHERE @ScanTimestampUTC >= d.KVK_REGISTRATION_DATE
          AND @ScanTimestampUTC <= d.KVK_END_DATE
        ORDER BY d.KVK_NO DESC;

        IF @KVK_NO IS NULL
            THROW 50005, 'Scan timestamp does not fall within any KVK_Details range.', 1;

        DECLARE @ScanID INT;

        BEGIN TRY
            BEGIN TRANSACTION;

            -- Duplicate-ingest guard: UPDLOCK/HOLDLOCK remain active for the
            -- lifetime of this transaction, serialising concurrent callers.
            IF EXISTS (
                SELECT 1
                FROM KVK.KVK_Scan WITH (UPDLOCK, HOLDLOCK)
                WHERE KVK_NO = @KVK_NO
                  AND ScanTimestampUTC = @ScanTimestampUTC
                  AND FileHash = @FileHash
            )
            BEGIN
                THROW 50006, 'Duplicate ingest: same KVK, ScanTimestamp, and FileHash already exists.', 1;
            END

            -- ScanID allocation: serialised by the same transaction/lock scope above.
            SELECT @ScanID = ISNULL(MAX(ScanID), 0) + 1
            FROM KVK.KVK_Scan WITH (UPDLOCK, HOLDLOCK)
            WHERE KVK_NO = @KVK_NO;

            INSERT INTO KVK.KVK_Scan
            (
                KVK_NO, ScanID, ScanTimestampUTC, SourceFileName, FileHash,
                Row_Count, ImportedAtUTC, UploaderDiscordID,
                schema_version, source_sheet_name, source_column_hash,
                source_column_count, source_row_count
            )
            VALUES
            (
                @KVK_NO, @ScanID, @ScanTimestampUTC, @SourceFileName, @FileHash,
                @OutRowCount, SYSUTCDATETIME(), @UploaderDiscordID,
                @SchemaVersion, @SourceSheetName, @SourceColumnHash,
                @SourceColumnCount, @SourceRowCount
            );

            INSERT INTO KVK.KVK_AllPlayers_Raw
            (
                KVK_NO, ScanID, governor_id, [name], kingdom, campid,
                [rank], min_kill_points, max_kill_points, min_power_raw, max_power_raw,
                min_dead, max_dead, min_troop_power, max_troop_power,
                min_units_healed, max_units_healed, min_kills_iv, max_kills_iv,
                min_kills_v, max_kills_v, min_max_contribute, max_max_contribute,
                min_cur_contribute, max_cur_contribute, max_contribute_diff,
                cur_contribute_diff,
                min_points, max_points, points_difference,
                min_power, max_power, power_difference,
                first_updateUTC, last_updateUTC,
                latest_power, kill_points_diff, power_diff,
                dead_diff, troop_power_diff, max_units_healed_diff, healed_troops,
                kills_iv_diff, kills_v_diff, subscription_level,
                schema_version, source_sheet_name, source_column_hash,
                source_column_count, source_row_count
            )
            SELECT
                @KVK_NO, @ScanID,
                s.governor_id, s.[name], s.kingdom, s.campid,
                s.[rank], s.min_kill_points, s.max_kill_points, s.min_power_raw, s.max_power_raw,
                s.min_dead, s.max_dead, s.min_troop_power, s.max_troop_power,
                s.min_units_healed, s.max_units_healed, s.min_kills_iv, s.max_kills_iv,
                s.min_kills_v, s.max_kills_v, s.min_max_contribute, s.max_max_contribute,
                s.min_cur_contribute, s.max_cur_contribute, s.max_contribute_diff,
                s.cur_contribute_diff,
                s.min_points, s.max_points, s.points_difference,
                s.min_power, s.max_power, s.power_difference,
                s.first_updateUTC, s.last_updateUTC,
                s.latest_power, s.kill_points_diff, s.power_diff,
                s.dead_diff, s.troop_power_diff, s.max_units_healed_diff, s.healed_troops,
                s.kills_iv_diff, s.kills_v_diff, s.subscription_level,
                COALESCE(s.schema_version, @SchemaVersion),
                COALESCE(s.source_sheet_name, @SourceSheetName),
                COALESCE(s.source_column_hash, @SourceColumnHash),
                COALESCE(s.source_column_count, @SourceColumnCount),
                COALESCE(s.source_row_count, @SourceRowCount)
            FROM KVK.KVK_AllPlayers_Stage AS s
            WHERE s.IngestToken = @IngestToken;

            INSERT INTO KVK.KVK_Player_Baseline (KVK_NO, governor_id, baseline_scan_id, starting_power)
            SELECT DISTINCT
                @KVK_NO, s.governor_id, @ScanID, ISNULL(s.max_power, 0)
            FROM KVK.KVK_AllPlayers_Stage AS s
            LEFT JOIN KVK.KVK_Player_Baseline AS b
                   ON b.KVK_NO = @KVK_NO AND b.governor_id = s.governor_id
            WHERE s.IngestToken = @IngestToken
              AND b.governor_id IS NULL;

            INSERT INTO KVK.KVK_Ingest_Negatives
            (
                KVK_NO, ScanID, governor_id, [name], kingdom, campid, field_name, [value], recorded_at_utc
            )
            SELECT
                @KVK_NO, @ScanID, x.governor_id, x.[name], x.kingdom, x.campid, v.field_name, v.val, SYSUTCDATETIME()
            FROM
            (
                SELECT s.governor_id, s.[name], s.kingdom, s.campid,
                       s.points_difference, s.kills_iv_diff, s.kills_v_diff,
                       s.dead_diff, s.max_units_healed_diff,
                       s.max_contribute_diff, s.cur_contribute_diff
                FROM KVK.KVK_AllPlayers_Stage AS s
                WHERE s.IngestToken = @IngestToken
            ) AS x
            CROSS APPLY
            (
                VALUES
                  (N'points_difference',      x.points_difference),
                  (N'kills_iv_diff',          x.kills_iv_diff),
                  (N'kills_v_diff',           x.kills_v_diff),
                  (N'dead_diff',              x.dead_diff),
                  (N'max_units_healed_diff',  x.max_units_healed_diff),
                  (N'max_contribute_diff',    x.max_contribute_diff),
                  (N'cur_contribute_diff',    x.cur_contribute_diff)
            ) AS v(field_name, val)
            WHERE v.val IS NOT NULL AND v.val < 0;

            DELETE FROM KVK.KVK_AllPlayers_Stage WHERE IngestToken = @IngestToken;

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;

        SET @OutKVK_NO = @KVK_NO;
        SET @OutScanID = @ScanID;

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(4000) = CONCAT(
            'Ingest failed (token=', CONVERT(VARCHAR(36), @IngestToken), '): ',
            ERROR_MESSAGE()
        );
        THROW 50010, @msg, 1;
    END CATCH
END
