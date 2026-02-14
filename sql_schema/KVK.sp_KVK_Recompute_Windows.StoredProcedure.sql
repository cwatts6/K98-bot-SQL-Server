SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[sp_KVK_Recompute_Windows]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [KVK].[sp_KVK_Recompute_Windows] AS' 
END
ALTER PROCEDURE [KVK].[sp_KVK_Recompute_Windows]
	@KVK_NO [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    ----------------------------------------------------------------
    -- 0) Validations & setup
    ----------------------------------------------------------------
    IF @KVK_NO IS NULL
        THROW 60001, 'KVK_NO is required.', 1;

    DECLARE @MaxScanID INT;
    SELECT @MaxScanID = MAX(ScanID)
    FROM KVK.KVK_Scan WITH (READCOMMITTEDLOCK)
    WHERE KVK_NO = @KVK_NO;

    IF @MaxScanID IS NULL
        THROW 60002, 'No scans exist for this KVK_NO.', 1;

    DECLARE @X FLOAT, @Y FLOAT, @Z FLOAT;

    SELECT TOP (1)
        @X = WeightT4X, @Y = WeightT5Y, @Z = WeightDeadsZ
    FROM KVK.KVK_DKPWeights WITH (READCOMMITTEDLOCK)
    WHERE KVK_NO = @KVK_NO
    ORDER BY EffectiveFromUTC DESC;

    IF @X IS NULL OR @Y IS NULL OR @Z IS NULL
        THROW 60003, 'DKP weights not defined for this KVK.', 1;

    ----------------------------------------------------------------
    -- 1) Clear existing outputs for this KVK (full overwrite)
	--    Keep Camp/Kingdom single-shot (small), batch Player (largest) for predictability.
    ----------------------------------------------------------------
    DELETE FROM KVK.KVK_Camp_Windowed    WHERE KVK_NO = @KVK_NO;
    DELETE FROM KVK.KVK_Kingdom_Windowed WHERE KVK_NO = @KVK_NO;
 
    DECLARE @DeleteBatchSize INT = 20000;

    DECLARE @RowsDeleted INT;

    WHILE 1 = 1
    BEGIN
        DELETE TOP (@DeleteBatchSize) p
        FROM KVK.KVK_Player_Windowed p WITH (INDEX(PK_KVK_Player_Windowed), PAGLOCK)
        WHERE p.KVK_NO = @KVK_NO;

        SET @RowsDeleted = @@ROWCOUNT;

        IF @RowsDeleted = 0 BREAK;
        IF @RowsDeleted < @DeleteBatchSize BREAK; -- typically avoids one extra terminal no-op pass
    END;

    ----------------------------------------------------------------
    -- 2) Baseline rows (validation view): zeros + fixed starting_power
    ----------------------------------------------------------------
    ;WITH base AS (
        SELECT b.KVK_NO,
               b.governor_id,
               b.starting_power,
               b.baseline_scan_id,
               r.name,
               r.kingdom
        FROM KVK.KVK_Player_Baseline b
        LEFT JOIN KVK.KVK_AllPlayers_Raw r
               ON r.KVK_NO = b.KVK_NO
              AND r.ScanID = b.baseline_scan_id
              AND r.governor_id = b.governor_id
        WHERE b.KVK_NO = @KVK_NO
    ),
    cm AS (
        SELECT KVK_NO, Kingdom, CampID, CampName
        FROM KVK.KVK_CampMap
        WHERE KVK_NO = @KVK_NO
    )
    INSERT INTO KVK.KVK_Player_Windowed
    (
        KVK_NO, WindowName, governor_id, name, kingdom, campid,
        kp_gain, kp_gain_recalc, kills_gain, t4_kills, t5_kills,
        kp_loss, healed_troops, deads, starting_power, dkp,
        last_scan_id, computed_at_utc
    )
    SELECT  @KVK_NO, N'Baseline', b.governor_id, b.name, b.kingdom,
            ISNULL(cm.CampID, 0),
            0, 0, 0, 0, 0,
            0, 0, 0, b.starting_power, 0.0,
            b.baseline_scan_id, SYSUTCDATETIME()
    FROM base b
    LEFT JOIN cm
      ON cm.KVK_NO = b.KVK_NO AND cm.Kingdom = b.kingdom;

    ----------------------------------------------------------------
    -- 3) Windowed deltas (Start→End, End defaults to MaxScanID)
    --    Window delta = End cumulative - Start cumulative
    ----------------------------------------------------------------
	;WITH W AS (
		SELECT
			RTRIM(w.WindowName) AS WindowName,
			w.StartScanID,
			-- Auto-cap EndScanID to max available scan (prevents future scan references)
			CASE 
				WHEN w.EndScanID IS NULL THEN @MaxScanID
				WHEN w.EndScanID > @MaxScanID THEN @MaxScanID  -- ← NEW: Safety cap
				ELSE w.EndScanID
			END AS EndScanID
		FROM KVK.KVK_Windows w WITH (READCOMMITTEDLOCK)
		WHERE w.KVK_NO = @KVK_NO
		  AND w.StartScanID IS NOT NULL
		  AND w.WindowName <> N'Baseline'
	),
    S AS (
        SELECT
            W.WindowName, W.StartScanID, W.EndScanID,
            r.governor_id, r.name, r.kingdom,
            ISNULL(r.points_difference,0)     AS kp_s,
            ISNULL(r.kills_iv_diff,0)         AS t4_s,
            ISNULL(r.kills_v_diff,0)          AS t5_s,
            ISNULL(r.dead_diff,0)             AS deads_s,
            ISNULL(r.max_units_healed_diff,0) AS heals_s
        FROM W
        JOIN KVK.KVK_AllPlayers_Raw r
          ON r.KVK_NO = @KVK_NO
         AND r.ScanID = W.StartScanID
    ),
    E AS (
        SELECT
            W.WindowName, W.StartScanID, W.EndScanID,
            r.governor_id, r.name, r.kingdom,
            ISNULL(r.points_difference,0)     AS kp_e,
            ISNULL(r.kills_iv_diff,0)         AS t4_e,
            ISNULL(r.kills_v_diff,0)          AS t5_e,
            ISNULL(r.dead_diff,0)             AS deads_e,
            ISNULL(r.max_units_healed_diff,0) AS heals_e
        FROM W
        JOIN KVK.KVK_AllPlayers_Raw r
          ON r.KVK_NO = @KVK_NO
         AND r.ScanID = W.EndScanID
    ),
    U AS (
        -- Full outer join: include govs that appear in Start or End (defensive)
        SELECT
            COALESCE(S.WindowName, E.WindowName) AS WindowName,
            COALESCE(S.StartScanID, E.StartScanID) AS StartScanID,
            COALESCE(S.EndScanID,   E.EndScanID)   AS EndScanID,
            COALESCE(S.governor_id, E.governor_id) AS governor_id,
            COALESCE(E.name, S.name)               AS name,
            COALESCE(E.kingdom, S.kingdom)         AS kingdom,
            -- Deltas
            ISNULL(E.kp_e,0)    - ISNULL(S.kp_s,0)    AS kp_gain,
            (ISNULL(E.t4_e,0)+ISNULL(E.t5_e,0))
          - (ISNULL(S.t4_s,0)+ISNULL(S.t5_s,0))       AS kills_gain,
            ISNULL(E.t4_e,0)   - ISNULL(S.t4_s,0)     AS t4_kills,
            ISNULL(E.t5_e,0)   - ISNULL(S.t5_s,0)     AS t5_kills,
            ISNULL(E.heals_e,0)- ISNULL(S.heals_s,0)  AS healed_troops,
            ISNULL(E.deads_e,0)- ISNULL(S.deads_s,0)  AS deads
        FROM S
        FULL OUTER JOIN E
          ON E.WindowName = S.WindowName
         AND E.StartScanID = S.StartScanID
         AND E.EndScanID   = S.EndScanID
         AND E.governor_id = S.governor_id
    ),
    B AS (
        SELECT b.governor_id, b.starting_power
        FROM KVK.KVK_Player_Baseline b WITH (READCOMMITTEDLOCK)
        WHERE b.KVK_NO = @KVK_NO
    ),
    CM AS (
        SELECT KVK_NO, Kingdom, CampID, CampName
        FROM KVK.KVK_CampMap WITH (READCOMMITTEDLOCK)
        WHERE KVK_NO = @KVK_NO
    )
    INSERT INTO KVK.KVK_Player_Windowed
    (
        KVK_NO, WindowName, governor_id, name, kingdom, campid,
        kp_gain, kp_gain_recalc, kills_gain, t4_kills, t5_kills,
        kp_loss, healed_troops, deads, starting_power, dkp,
        last_scan_id, computed_at_utc
    )
    SELECT
        @KVK_NO,
        RTRIM(U.WindowName),
        U.governor_id,
        U.name,
        U.kingdom,
        ISNULL(CM.CampID, 0) AS campid,
        -- KP Gain (source-of-truth)
        U.kp_gain,
        -- KP Gain (recalc) = 10*T4 + 20*T5
        (U.t4_kills * 10) + (U.t5_kills * 20) AS kp_gain_recalc,
        U.kills_gain,
        U.t4_kills,
        U.t5_kills,
        -- KP Loss = heals * 20
        (U.healed_troops * 20) AS kp_loss,
        U.healed_troops,
        U.deads,
        ISNULL(B.starting_power, 0) AS starting_power,
        CASE WHEN ISNULL(B.starting_power,0) > 0
             THEN ((U.t4_kills * @X) + (U.t5_kills * @Y) + (U.deads * @Z))
             ELSE 0.0 END AS dkp,
        U.EndScanID,
        SYSUTCDATETIME()
    FROM U
    LEFT JOIN B  ON B.governor_id = U.governor_id
    LEFT JOIN CM ON CM.KVK_NO = @KVK_NO AND CM.Kingdom = U.kingdom;

    ----------------------------------------------------------------
    -- 4) Full KVK (Baseline→MaxScanID): use latest cumulative snapshot
    ----------------------------------------------------------------
    ;WITH E AS (
        SELECT r.governor_id, r.name, r.kingdom,
               ISNULL(r.points_difference,0)     AS kp,
               ISNULL(r.kills_iv_diff,0)         AS t4,
               ISNULL(r.kills_v_diff,0)          AS t5,
               ISNULL(r.dead_diff,0)             AS deads,
               ISNULL(r.max_units_healed_diff,0) AS heals
        FROM KVK.KVK_AllPlayers_Raw r WITH (READCOMMITTEDLOCK)
        WHERE r.KVK_NO = @KVK_NO
          AND r.ScanID = @MaxScanID
    ),
    B AS (
        SELECT governor_id, starting_power
        FROM KVK.KVK_Player_Baseline WITH (READCOMMITTEDLOCK)
        WHERE KVK_NO = @KVK_NO
    ),
    CM AS (
        SELECT KVK_NO, Kingdom, CampID, CampName
        FROM KVK.KVK_CampMap WITH (READCOMMITTEDLOCK)
        WHERE KVK_NO = @KVK_NO
    )
    INSERT INTO KVK.KVK_Player_Windowed
    (
        KVK_NO, WindowName, governor_id, name, kingdom, campid,
        kp_gain, kp_gain_recalc, kills_gain, t4_kills, t5_kills,
        kp_loss, healed_troops, deads, starting_power, dkp,
        last_scan_id, computed_at_utc
    )
    SELECT
        @KVK_NO,
        N'Full',
        E.governor_id,
        E.name,
        E.kingdom,
        ISNULL(CM.CampID, 0),
        -- Full uses cumulative since baseline (End-only)
        E.kp,
        (E.t4 * 10) + (E.t5 * 20) AS kp_gain_recalc,
        (E.t4 + E.t5)             AS kills_gain,
        E.t4, E.t5,
        (E.heals * 20)            AS kp_loss,
        E.heals,
        E.deads,
        ISNULL(B.starting_power, 0) AS starting_power,
        CASE WHEN ISNULL(B.starting_power,0) > 0
             THEN ((E.t4 * @X) + (E.t5 * @Y) + (E.deads * @Z))
             ELSE 0.0 END AS dkp,
        @MaxScanID,
        SYSUTCDATETIME()
    FROM E
    LEFT JOIN B  ON B.governor_id = E.governor_id
    LEFT JOIN CM ON CM.KVK_NO = @KVK_NO AND CM.Kingdom = E.kingdom;

    ----------------------------------------------------------------
    -- 5) Rollups (Kingdom & Camp) from Player_Windowed just written
    ----------------------------------------------------------------
    -- Kingdom
    ;WITH P AS (
		SELECT *
		FROM KVK.KVK_Player_Windowed WITH (READCOMMITTEDLOCK)
		WHERE KVK_NO = @KVK_NO
	),
	CM AS (
		SELECT KVK_NO, Kingdom, CampID, CampName
		FROM KVK.KVK_CampMap WITH (READCOMMITTEDLOCK)
		WHERE KVK_NO = @KVK_NO
	),
	K AS (
		SELECT
			@KVK_NO AS KVK_NO,
			p.WindowName,
			p.kingdom,
			ISNULL(cm.CampID, 0)        AS campid,
			ISNULL(cm.CampName, N'')    AS camp_name,
			SUM(p.kp_gain)              AS kp_gain,
			SUM(p.kp_gain_recalc)       AS kp_gain_recalc, -- only used for DKP calc here
			SUM(p.kills_gain)           AS kills_gain,
			SUM(p.t4_kills)             AS t4_kills,
			SUM(p.t5_kills)             AS t5_kills,
			SUM(p.kp_loss)              AS kp_loss,
			SUM(p.healed_troops)        AS healed_troops,
			SUM(p.deads)                AS deads,
			SUM(p.starting_power)       AS starting_power_sum,
			MAX(p.last_scan_id)         AS last_scan_id
		FROM P p
		LEFT JOIN CM
		  ON CM.KVK_NO = @KVK_NO
		 AND CM.Kingdom = p.kingdom
		GROUP BY p.WindowName, p.kingdom, ISNULL(cm.CampID, 0), ISNULL(cm.CampName, N'')
	)
	INSERT INTO KVK.KVK_Kingdom_Windowed
	(
		KVK_NO, WindowName, kingdom, campid, camp_name,
		kp_gain, kills_gain, t4_kills, t5_kills,
		kp_loss, healed_troops, deads, dkp,
		last_scan_id, computed_at_utc
	)
	SELECT
		K.KVK_NO, K.WindowName, K.kingdom, K.campid, K.camp_name,
		K.kp_gain, K.kills_gain, K.t4_kills, K.t5_kills,
		K.kp_loss, K.healed_troops, K.deads,
		CASE WHEN K.starting_power_sum > 0
			 THEN ((K.t4_kills * @X) + (K.t5_kills * @Y) + (K.deads * @Z))
			 ELSE 0.0 END AS dkp,
		K.last_scan_id,
		SYSUTCDATETIME()
	FROM K;

    -- Camp
    ;WITH P AS (
        SELECT *
        FROM KVK.KVK_Player_Windowed WITH (READCOMMITTEDLOCK)
        WHERE KVK_NO = @KVK_NO
    ),
    CM AS (
        SELECT KVK_NO, Kingdom, CampID, CampName
        FROM KVK.KVK_CampMap WITH (READCOMMITTEDLOCK)
        WHERE KVK_NO = @KVK_NO
    ),
    C AS (
        SELECT
            @KVK_NO AS KVK_NO,
            p.WindowName,
            ISNULL(cm.CampID, 0)   AS campid,
            ISNULL(cm.CampName, N'') AS camp_name,
            SUM(p.kp_gain)         AS kp_gain,
            SUM(p.kills_gain)      AS kills_gain,
            SUM(p.t4_kills)        AS t4_kills,
            SUM(p.t5_kills)        AS t5_kills,
            SUM(p.kp_loss)         AS kp_loss,
            SUM(p.healed_troops)   AS healed_troops,
            SUM(p.deads)           AS deads,
            SUM(p.starting_power)  AS starting_power_sum,
            MAX(p.last_scan_id)    AS last_scan_id
        FROM P p
        LEFT JOIN CM
          ON CM.KVK_NO = @KVK_NO AND CM.Kingdom = p.kingdom
        GROUP BY p.WindowName, ISNULL(cm.CampID, 0), ISNULL(cm.CampName, N'')
    )
    INSERT INTO KVK.KVK_Camp_Windowed
    (
        KVK_NO, WindowName, campid, camp_name,
        kp_gain, kills_gain, t4_kills, t5_kills,
        kp_loss, healed_troops, deads, dkp,
        last_scan_id, computed_at_utc
    )
    SELECT
        C.KVK_NO, C.WindowName, C.campid, C.camp_name,
        C.kp_gain, C.kills_gain, C.t4_kills, C.t5_kills,
        C.kp_loss, C.healed_troops, C.deads,
        CASE WHEN C.starting_power_sum > 0
             THEN ((C.t4_kills * @X) + (C.t5_kills * @Y) + (C.deads * @Z))
             ELSE 0.0 END AS dkp,
        C.last_scan_id,
        SYSUTCDATETIME()
    FROM C;

    RETURN 0;
END

