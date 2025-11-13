SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TARGETS]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[TARGETS] AS' 
END
ALTER PROCEDURE [dbo].[TARGETS]
	@InputScanOrder [float] = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY

        DECLARE @BAND1 FLOAT = 100000000,
                @BAND2 FLOAT = 90000000,
                @BAND3 FLOAT = 80000000,
                @BAND4 FLOAT = 70000000,
                @BAND5 FLOAT = 60000000,
                @BAND6 FLOAT = 50000000,
                @BAND7 FLOAT = 40000000,
                @MATCHMAKINGSCAN FLOAT = ISNULL(@InputScanOrder, (SELECT MAX(SCANORDER) FROM KingdomScanData4));

        -- Clear previous target data
        TRUNCATE TABLE TARGETS_JUN25;

        -- Insert calculated targets
        INSERT INTO TARGETS_JUN25 (GovernorID, Kill_Target, Minimum_Kill_Target, Dead_Target)
        SELECT GovernorID,
               CASE
                   WHEN Power >= @BAND1 THEN 15000000
                   WHEN Power >= @BAND2 THEN 15000000
                   WHEN Power >= @BAND3 THEN 8000000
                   WHEN Power >= @BAND4 THEN 6000000
                   WHEN Power >= @BAND5 THEN 5000000
                   WHEN Power >= @BAND6 THEN 4000000
                   WHEN Power >= @BAND7 THEN 2500000
                   ELSE 0
               END AS Kill_Target,
               CASE
                   WHEN Power >= @BAND1 THEN 6000000
                   WHEN Power >= @BAND2 THEN 6000000
                   WHEN Power >= @BAND3 THEN 3000000
                   WHEN Power >= @BAND4 THEN 2000000
                   WHEN Power >= @BAND5 THEN 1000000
                   WHEN Power >= @BAND6 THEN 1000000
                   WHEN Power >= @BAND7 THEN 1000000
                   ELSE 0
               END AS Minimum_Kill_Target,
               CASE
                   WHEN Power >= @BAND1 THEN 1250000
                   WHEN Power >= @BAND2 THEN 1000000
                   WHEN Power >= @BAND3 THEN 800000
                   WHEN Power >= @BAND4 THEN 500000
                   WHEN Power >= @BAND5 THEN 500000
                   WHEN Power >= @BAND6 THEN 300000
                   WHEN Power >= @BAND7 THEN 300000
                   ELSE 0
               END AS Dead_Target
        FROM KingdomScanData4
        WHERE SCANORDER = @MATCHMAKINGSCAN;

        -- Prep staging table
        TRUNCATE TABLE EXCEL_OUTPUT_KVK_TARGETS_JUN25;

        -- Load power rankings into temp table
        SELECT GovernorID, GovernorName, Power, [Troops Power], [City Hall],
               [Tech Power], [Building Power], [Commander Power],
               ROW_NUMBER() OVER (ORDER BY Power DESC) AS PowerRank
        INTO #P
        FROM KingdomScanData4
        WHERE SCANORDER = @MATCHMAKINGSCAN
          AND GovernorID NOT IN (22345012, 46718337, 2510418, 83724180, 17868677, 12025033);

        -- Insert full KVK target view
        INSERT INTO EXCEL_OUTPUT_KVK_TARGETS_JUN25
        SELECT TOP 5000
               P.PowerRank AS Rank,
               ROW_NUMBER() OVER (ORDER BY P.Power DESC) AS RANK2,
               P.GovernorID AS Gov_ID,
               RTRIM(P.GovernorName) AS Governor_Name,
               FORMAT(P.Power, '#,###') AS Power,
               P.[City Hall],
               FORMAT(P.[Troops Power], '#,###') AS [Troops Power],
               FORMAT(P.[Tech Power], '#,###') AS [Tech Power],
               FORMAT(P.[Building Power], '#,###') AS [Building Power],
               FORMAT(P.[Commander Power], '#,###') AS [Commander Power],
               T.Kill_Target,
               T.Minimum_Kill_Target,
               T.Dead_Target,
               (T.Kill_Target * 3 + T.Dead_Target * 8) AS [DKP Target],
               LK.[t4&t5_kills], LK.deads, LK.dkp_score, LK.[% of DKP Target],
               JK.[t4&t5_kills], JK.deads, JK.dkp_score, JK.[% of DKP Target]
        FROM #P AS P
        JOIN TARGETS_JUN25 AS T ON T.GovernorID = P.GovernorID
        LEFT JOIN EXCEL_FOR_MAR25_KVK AS LK ON LK.Gov_ID = P.GovernorID
        LEFT JOIN EXCEL_FOR_JAN25_KVK AS JK ON JK.Gov_ID = P.GovernorID
        ORDER BY P.Power ASC;

        DROP TABLE IF EXISTS #P;

        -- Prepare export table
        TRUNCATE TABLE EXCEL_EXPORT_KVK_TARGETS_JUN25;

        -- Export top 350 to simplified table
        INSERT INTO EXCEL_EXPORT_KVK_TARGETS_JUN25
        SELECT TOP 350
               RANK2 AS [Rank],
               Gov_ID,
               Governor_Name,
               [Power],
               [City Hall] AS [CH],
               [Troops Power],
               [Tech Power],
               [Building Power],
               [Commander Power],
               '' AS B1,
               [Kill Target],
               [Minimum Kill Target],
               [Dead Target],
               [DKP Target],
               '' AS B2,
               [Kills Mar25 KVK],
               [DEADS Mar25 KVK],
               [DKP Mar25 KVK],
               [% DKP Target Mar25 KVK] AS [% DKP Mar25 KVK],
               '' AS B3,
               [Kills Jan25 KVK],
               [DEADS Jan25 KVK],
               [DKP Jan25 KVK],
               [% DKP Target Jan25 KVK] AS [% DKP Jan25 KVK]
        FROM EXCEL_OUTPUT_KVK_TARGETS_JUN25
        ORDER BY RANK2 ASC;

    END TRY
    BEGIN CATCH
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        DECLARE @ErrSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR('TARGETS procedure failed: %s', @ErrSeverity, @ErrState, @ErrMsg);
    END CATCH
END



             
