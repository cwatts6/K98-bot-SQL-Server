/*
MigrationId: 20260628_001_import_schema_resilience_and_shield_time
Purpose: Import schema resilience metadata and player location shield support
Author: cwatts
CreatedUtc: 2026-06-28
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: N/A for schema-only additive changes
PreValidationQuery: SELECT OBJECT_ID(N'dbo.FallbackImportBatchControl') AS ControlTable, COL_LENGTH(N'dbo.PlayerLocation', N'ShieldEndsAtUnix') AS PlayerShieldUnix;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.FallbackImportBatchControl') AS ControlTable, COL_LENGTH(N'dbo.PlayerLocation', N'ShieldEndsAtUnix') AS PlayerShieldUnix, COL_LENGTH(N'dbo.PlayerLocation_Staging', N'ShieldEndsAtUnix') AS StagingShieldUnix;
DataSafetyPlanNotes:
- Adds nullable shield fields to player location staging/final storage.
- Adds fallback import batch metadata so bot-side schema detection is visible to SQL operators.
- Updates player location import procedures and v_PlayerProfile to project shield fields.
- Bot code must be deployed after this migration for new shield inserts and metadata writes.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.FallbackImportBatchControl', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FallbackImportBatchControl
    (
        ControlId bigint IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_FallbackImportBatchControl PRIMARY KEY CLUSTERED,
        CreatedAtUtc datetime2(0) NOT NULL
            CONSTRAINT DF_FallbackImportBatchControl_CreatedAtUtc DEFAULT SYSUTCDATETIME(),
        SourceType nvarchar(64) COLLATE Latin1_General_CI_AS NOT NULL,
        SourceFilename nvarchar(260) COLLATE Latin1_General_CI_AS NULL,
        ScoreHeader nvarchar(64) COLLATE Latin1_General_CI_AS NULL,
        ColumnsPresentJson nvarchar(max) COLLATE Latin1_General_CI_AS NULL,
        RowsInSource int NULL,
        RowsWritten int NULL
    );
END;

IF OBJECT_ID(N'dbo.FallbackImportBatchControl', N'U') IS NOT NULL
   AND NOT EXISTS (
        SELECT 1
        FROM sys.default_constraints dc
        INNER JOIN sys.columns c
            ON c.object_id = dc.parent_object_id
           AND c.column_id = dc.parent_column_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.FallbackImportBatchControl')
          AND c.name = N'CreatedAtUtc'
    )
BEGIN
    ALTER TABLE dbo.FallbackImportBatchControl
        ADD CONSTRAINT DF_FallbackImportBatchControl_CreatedAtUtc
        DEFAULT SYSUTCDATETIME() FOR CreatedAtUtc;
END;

IF COL_LENGTH(N'dbo.PlayerLocation_Staging', N'ShieldEndsAtUnix') IS NULL
    ALTER TABLE dbo.PlayerLocation_Staging ADD ShieldEndsAtUnix bigint NULL;

IF COL_LENGTH(N'dbo.PlayerLocation_Staging', N'ShieldEndsAtUtc') IS NULL
    ALTER TABLE dbo.PlayerLocation_Staging ADD ShieldEndsAtUtc datetime2(0) NULL;

IF COL_LENGTH(N'dbo.PlayerLocation', N'ShieldEndsAtUnix') IS NULL
    ALTER TABLE dbo.PlayerLocation ADD ShieldEndsAtUnix bigint NULL;

IF COL_LENGTH(N'dbo.PlayerLocation', N'ShieldEndsAtUtc') IS NULL
    ALTER TABLE dbo.PlayerLocation ADD ShieldEndsAtUtc datetime2(0) NULL;

EXEC dbo.sp_executesql N'
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
            ShieldEndsAtUnix,
            CASE
                WHEN ShieldEndsAtUtc IS NOT NULL THEN ShieldEndsAtUtc
                WHEN ShieldEndsAtUnix IS NULL OR ShieldEndsAtUnix <= 0 THEN NULL
                WHEN ShieldEndsAtUnix > 2147483647 THEN NULL
                ELSE DATEADD(SECOND, ShieldEndsAtUnix, CONVERT(datetime2(0), ''1970-01-01''))
            END AS ShieldEndsAtUtc,
            ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ImportedAt DESC) AS rn
        FROM dbo.PlayerLocation_Staging
        WHERE x IS NOT NULL AND y IS NOT NULL
    )
    MERGE dbo.PlayerLocation AS tgt
    USING (
        SELECT GovernorID, X, Y, ShieldEndsAtUnix, ShieldEndsAtUtc
        FROM Latest
        WHERE rn = 1
    ) AS src
        ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED AND (
            tgt.X <> src.X
         OR tgt.Y <> src.Y
         OR ISNULL(tgt.ShieldEndsAtUnix, -1) <> ISNULL(src.ShieldEndsAtUnix, -1)
         OR ISNULL(tgt.ShieldEndsAtUtc, CONVERT(datetime2(0), ''1900-01-01'')) <> ISNULL(src.ShieldEndsAtUtc, CONVERT(datetime2(0), ''1900-01-01''))
    ) THEN
        UPDATE SET
            X = src.X,
            Y = src.Y,
            ShieldEndsAtUnix = src.ShieldEndsAtUnix,
            ShieldEndsAtUtc = src.ShieldEndsAtUtc,
            LastUpdated = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (GovernorID, X, Y, ShieldEndsAtUnix, ShieldEndsAtUtc, LastUpdated)
        VALUES (src.GovernorID, src.X, src.Y, src.ShieldEndsAtUnix, src.ShieldEndsAtUtc, SYSUTCDATETIME());

    SELECT
        (SELECT COUNT(*) FROM dbo.PlayerLocation_Staging) AS StagingRows,
        (SELECT COUNT(*) FROM dbo.PlayerLocation)        AS TotalTracked;
END;
';

EXEC dbo.sp_executesql N'
ALTER PROCEDURE [dbo].[sp_ReplacePlayerLocationFromStaging]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Latest AS (
        SELECT
            CAST(player_id AS BIGINT) AS GovernorID,
            CAST(x AS INT) AS X,
            CAST(y AS INT) AS Y,
            ShieldEndsAtUnix,
            CASE
                WHEN ShieldEndsAtUtc IS NOT NULL THEN ShieldEndsAtUtc
                WHEN ShieldEndsAtUnix IS NULL OR ShieldEndsAtUnix <= 0 THEN NULL
                WHEN ShieldEndsAtUnix > 2147483647 THEN NULL
                ELSE DATEADD(SECOND, ShieldEndsAtUnix, CONVERT(datetime2(0), ''1970-01-01''))
            END AS ShieldEndsAtUtc,
            ROW_NUMBER() OVER (PARTITION BY player_id ORDER BY ImportedAt DESC) AS rn
        FROM dbo.PlayerLocation_Staging
        WHERE x IS NOT NULL AND y IS NOT NULL
    )
    SELECT GovernorID, X, Y, ShieldEndsAtUnix, ShieldEndsAtUtc
    INTO #Src
    FROM Latest
    WHERE rn = 1;

    DECLARE @SrcCount INT = (SELECT COUNT(*) FROM #Src);

    IF @SrcCount = 0
    BEGIN
        RETURN;
    END

    BEGIN TRY
        BEGIN TRAN;

        TRUNCATE TABLE dbo.PlayerLocation;

        INSERT INTO dbo.PlayerLocation
            (GovernorID, X, Y, ShieldEndsAtUnix, ShieldEndsAtUtc, LastUpdated)
        SELECT GovernorID, X, Y, ShieldEndsAtUnix, ShieldEndsAtUtc, SYSUTCDATETIME()
        FROM #Src;

        COMMIT TRAN;

        SELECT @SrcCount AS ImportedRows,
               (SELECT COUNT(*) FROM dbo.PlayerLocation) AS TotalTracked;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END;
';

EXEC dbo.sp_executesql N'
ALTER VIEW [dbo].[v_PlayerProfile] AS
SELECT
    s.GovernorID,
    s.Governor_Name,
    s.Alliance,
    s.CityHallLevel,
    s.Power,
    s.Kills,
    s.Deads,
    s.RSS_Gathered,
    s.Helps,
    loc.X,
    loc.Y,
    loc.LastUpdated AS LocationUpdated,
    loc.ShieldEndsAtUnix,
    loc.ShieldEndsAtUtc,
    acc.Status,
    acc.UpdatedAt   AS StatusUpdated,
    f.FortsRank,
    f.FortsStarted,
    f.FortsJoined,
    f.FortsTotal,
    f.SnapshotAt    AS FortsUpdated,
    s.PowerRank,
    s.Conduct
FROM dbo.v_PlayerLatestStats AS s
LEFT JOIN dbo.PlayerLocation            AS loc ON loc.GovernorID = s.GovernorID
LEFT JOIN dbo.PlayerAccountStatus       AS acc ON acc.GovernorID = s.GovernorID
LEFT JOIN dbo.v_PlayerFortsLatestWithRank AS f ON f.GovernorID = s.GovernorID;
';
