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
	@OutRowCount [int] OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @err NVARCHAR(4000);

    BEGIN TRY
        -- 0) Basic validations
        IF @IngestToken IS NULL
            THROW 50001, 'IngestToken is required.', 1;
        IF @ScanTimestampUTC IS NULL
            THROW 50002, 'ScanTimestampUTC is required.', 1;
        IF @FileHash IS NULL OR DATALENGTH(@FileHash) = 0
            THROW 50003, 'FileHash is required (use SHA-256).', 1;

        -- 1) Ensure we actually have staged rows
        SELECT @OutRowCount = COUNT(*) 
        FROM KVK.KVK_AllPlayers_Stage WITH (READCOMMITTEDLOCK)
        WHERE IngestToken = @IngestToken;

        IF @OutRowCount IS NULL OR @OutRowCount = 0
            THROW 50004, 'No staged rows found for IngestToken.', 1;

        -- 2) Resolve KVK_NO from dbo.KVK_Details by timestamp
        DECLARE @KVK_NO INT;

        SELECT TOP(1) @KVK_NO = d.KVK_NO
        FROM dbo.KVK_Details AS d WITH (READCOMMITTEDLOCK)
        WHERE @ScanTimestampUTC >= d.KVK_REGISTRATION_DATE
          AND @ScanTimestampUTC <= d.KVK_END_DATE
        ORDER BY d.KVK_NO DESC;  -- latest match if overlapping; ideally none overlap

        IF @KVK_NO IS NULL
            THROW 50005, 'Scan timestamp does not fall within any KVK_Details range.', 1;

        -- 3) Duplicate rejection: same KVK + ScanTimestamp + FileHash
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

        -- 4) Allocate next ScanID (safe under concurrency)
        DECLARE @ScanID INT;

        SELECT @ScanID = ISNULL(MAX(ScanID), 0) + 1
        FROM KVK.KVK_Scan WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = @KVK_NO;

        -- 5) Insert scan header
        INSERT INTO KVK.KVK_Scan
        (
            KVK_NO, ScanID, ScanTimestampUTC, SourceFileName, FileHash,
            Row_Count, ImportedAtUTC, UploaderDiscordID
        )
        VALUES
        (
            @KVK_NO, @ScanID, @ScanTimestampUTC, @SourceFileName, @FileHash,
            @OutRowCount, SYSUTCDATETIME(), @UploaderDiscordID
        );

        -- 6) Move staged rows → raw (this preserves as-supplied values)
        INSERT INTO KVK.KVK_AllPlayers_Raw
        (
            KVK_NO, ScanID, governor_id, [name], kingdom, campid,
            min_points, max_points, points_difference,
            min_power, max_power, power_difference,
            first_updateUTC, last_updateUTC,
            latest_power, kill_points_diff, power_diff,
            dead_diff, troop_power_diff, max_units_healed_diff, healed_troops,
            kills_iv_diff, kills_v_diff, subscription_level
        )
        SELECT
            @KVK_NO, @ScanID,
            s.governor_id, s.[name], s.kingdom, s.campid,
            s.min_points, s.max_points, s.points_difference,
            s.min_power, s.max_power, s.power_difference,
            s.first_updateUTC, s.last_updateUTC,
            s.latest_power, s.kill_points_diff, s.power_diff,
            s.dead_diff, s.troop_power_diff, s.max_units_healed_diff, s.healed_troops,
            s.kills_iv_diff, s.kills_v_diff, s.subscription_level
        FROM KVK.KVK_AllPlayers_Stage AS s
        WHERE s.IngestToken = @IngestToken;

        -- 7) Initialize baselines for any governors new to this KVK
        INSERT INTO KVK.KVK_Player_Baseline (KVK_NO, governor_id, baseline_scan_id, starting_power)
        SELECT DISTINCT
            @KVK_NO, s.governor_id, @ScanID, ISNULL(s.max_power, 0)
        FROM KVK.KVK_AllPlayers_Stage AS s
        LEFT JOIN KVK.KVK_Player_Baseline AS b
               ON b.KVK_NO = @KVK_NO AND b.governor_id = s.governor_id
        WHERE s.IngestToken = @IngestToken
          AND b.governor_id IS NULL;

        -- 8) Negative Corrections Report (fidelity: log any negative deltas)
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
                   s.dead_diff, s.max_units_healed_diff
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
              (N'max_units_healed_diff',  x.max_units_healed_diff)
        ) AS v(field_name, val)
        WHERE v.val IS NOT NULL AND v.val < 0;

        -- 9) (Optional) Clear the stage rows for this token
        DELETE FROM KVK.KVK_AllPlayers_Stage WHERE IngestToken = @IngestToken;

        -- 10) Outputs
        SET @OutKVK_NO = @KVK_NO;
        SET @OutScanID = @ScanID;
        -- @OutRowCount already set above

        RETURN 0;
    END TRY
    BEGIN CATCH
        DECLARE @msg NVARCHAR(4000) = CONCAT(
            'Ingest failed (token=', CONVERT(VARCHAR(36), @IngestToken), '): ',
            ERROR_MESSAGE()
        );
        -- Do NOT delete stage rows on error; leave them for investigation.
        THROW 50010, @msg, 1;
    END CATCH
END

