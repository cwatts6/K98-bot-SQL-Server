SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_ImportPlayerLocationFromStaging]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_ImportPlayerLocationFromStaging] AS' 
END
ALTER PROCEDURE [dbo].[sp_ImportPlayerLocationFromStaging]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Latest AS (
        SELECT
            CAST(player_id AS BIGINT) AS GovernorID,
            CAST(x AS INT) AS X,
            CAST(y AS INT) AS Y,
            ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ImportedAt DESC) AS rn
        FROM dbo.PlayerLocation_Staging
        WHERE x IS NOT NULL AND y IS NOT NULL
    )
    MERGE dbo.PlayerLocation AS tgt
    USING (SELECT GovernorID, X, Y FROM Latest WHERE rn = 1) AS src
        ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED AND (tgt.X <> src.X OR tgt.Y <> src.Y) THEN
        UPDATE SET X = src.X, Y = src.Y, LastUpdated = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (GovernorID, X, Y, LastUpdated)
        VALUES (src.GovernorID, src.X, src.Y, SYSUTCDATETIME());

    SELECT
        (SELECT COUNT(*) FROM dbo.PlayerLocation_Staging) AS StagingRows,
        (SELECT COUNT(*) FROM dbo.PlayerLocation)        AS TotalTracked;
END;

