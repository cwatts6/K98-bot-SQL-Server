SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ReplacePlayerLocationFromStaging]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_ReplacePlayerLocationFromStaging] AS' 
END
ALTER PROCEDURE [dbo].[sp_ReplacePlayerLocationFromStaging]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    -- Dedupe to latest record per player (by ImportedAt)
    ;WITH Latest AS (
        SELECT
            CAST(player_id AS BIGINT) AS GovernorID,
            CAST(x AS INT) AS X,
            CAST(y AS INT) AS Y,
            ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ImportedAt DESC) AS rn
        FROM dbo.PlayerLocation_Staging
        WHERE x IS NOT NULL AND y IS NOT NULL
    )
    SELECT GovernorID, X, Y
    INTO #Src
    FROM Latest
    WHERE rn = 1;

    DECLARE @SrcCount INT = (SELECT COUNT(*) FROM #Src);

    IF @SrcCount = 0
    BEGIN
        -- Nothing to import: leave PlayerLocation unchanged
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        -- Full replace semantics
        TRUNCATE TABLE dbo.PlayerLocation;

        INSERT INTO dbo.PlayerLocation (GovernorID, X, Y, LastUpdated)
        SELECT GovernorID, X, Y, SYSUTCDATETIME()
        FROM #Src;

        COMMIT TRAN;

        -- Return counts for logging
        SELECT @SrcCount AS ImportedRows,
               (SELECT COUNT(*) FROM dbo.PlayerLocation) AS TotalTracked;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        -- Re-throw with original error info
        THROW;
    END CATCH
END;

