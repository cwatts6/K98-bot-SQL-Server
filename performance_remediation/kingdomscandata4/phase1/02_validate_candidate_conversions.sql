/*
Purpose: Read-only data-quality checks for proposed dbo.KingdomScanData4 type changes.
Cost: Scans the table and performs distinct aggregates. Use a restored copy or low-activity window.
Safety: No data or schema changes.
*/

SET NOCOUNT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF DB_NAME() <> N'ROK_TRACKER'
BEGIN
    THROW 51000, 'Run this collector only in the ROK_TRACKER database.', 1;
END;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
BEGIN
    THROW 51001, 'dbo.KingdomScanData4 does not exist in the target database.', 1;
END;

SELECT
    N'population' AS EvidenceSection,
    COUNT_BIG(*) AS ExactRowCount,
    COUNT_BIG(DISTINCT GovernorID) AS DistinctGovernorIdsAsFloat,
    COUNT_BIG(DISTINCT TRY_CONVERT(bigint, GovernorID)) AS DistinctGovernorIdsAsBigint,
    MIN(ScanDate) AS MinimumScanDate,
    MAX(ScanDate) AS MaximumScanDate,
    MIN(SCANORDER) AS MinimumScanOrder,
    MAX(SCANORDER) AS MaximumScanOrder
FROM dbo.KingdomScanData4;

;WITH CandidateValues AS (
    SELECT
        values_to_check.ColumnName,
        values_to_check.TargetType,
        values_to_check.CandidateValue
    FROM dbo.KingdomScanData4 AS source
    CROSS APPLY (VALUES
        (N'GovernorID', N'bigint', source.GovernorID),
        (N'PowerRank', N'int', source.PowerRank),
        (N'SCANORDER', N'int', source.SCANORDER),
        (N'Power', N'bigint', source.[Power]),
        (N'KillPoints', N'bigint', source.KillPoints),
        (N'Deads', N'bigint', source.Deads),
        (N'T1_Kills', N'bigint', source.T1_Kills),
        (N'T2_Kills', N'bigint', source.T2_Kills),
        (N'T3_Kills', N'bigint', source.T3_Kills),
        (N'T4_Kills', N'bigint', source.T4_Kills),
        (N'T5_Kills', N'bigint', source.T5_Kills),
        (N'T4&T5_KILLS', N'bigint', source.[T4&T5_KILLS]),
        (N'TOTAL_KILLS', N'bigint', source.TOTAL_KILLS),
        (N'RSS_Gathered', N'bigint', source.RSS_Gathered),
        (N'RSSAssistance', N'bigint', source.RSSAssistance),
        (N'Helps', N'bigint', source.Helps)
    ) AS values_to_check(ColumnName, TargetType, CandidateValue)
)
SELECT
    N'numeric_conversion_safety' AS EvidenceSection,
    ColumnName,
    TargetType,
    COUNT_BIG(*) AS [RowCount],
    SUM(CASE WHEN CandidateValue IS NULL THEN CONVERT(bigint, 1) ELSE 0 END) AS NullCount,
    COUNT_BIG(DISTINCT CandidateValue) AS DistinctSourceCount,
    MIN(CandidateValue) AS MinimumValue,
    MAX(CandidateValue) AS MaximumValue,
    SUM(CASE
        WHEN CandidateValue IS NOT NULL AND CandidateValue <> FLOOR(CandidateValue)
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS FractionalValueCount,
    SUM(CASE
        WHEN TargetType = N'int'
         AND CandidateValue IS NOT NULL
         AND (CandidateValue < -2147483648.0 OR CandidateValue > 2147483647.0)
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS IntOutOfRangeCount,
    SUM(CASE
        WHEN TargetType = N'bigint'
         AND CandidateValue IS NOT NULL
         AND TRY_CONVERT(bigint, CandidateValue) IS NULL
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS BigintFailedConversionCount,
    SUM(CASE
        WHEN CandidateValue IS NOT NULL AND ABS(CandidateValue) > 9007199254740992.0
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS BeyondExactFloatIntegerRangeCount
FROM CandidateValues
GROUP BY ColumnName, TargetType
ORDER BY ColumnName
OPTION (MAXDOP 1);

SELECT
    N'governor_id_conversion_summary' AS EvidenceSection,
    COUNT_BIG(*) AS [RowCount],
    COUNT_BIG(DISTINCT GovernorID) AS DistinctSourceValues,
    COUNT_BIG(DISTINCT TRY_CONVERT(bigint, GovernorID)) AS DistinctConvertedValues,
    SUM(CASE
        WHEN GovernorID <> FLOOR(GovernorID)
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS FractionalCount,
    SUM(CASE
        WHEN TRY_CONVERT(bigint, GovernorID) IS NULL
        THEN CONVERT(bigint, 1) ELSE 0
    END) AS FailedConversionCount
FROM dbo.KingdomScanData4
OPTION (MAXDOP 1);

;WITH GovernorConversions AS (
    SELECT
        TRY_CONVERT(bigint, GovernorID) AS ConvertedGovernorId,
        COUNT_BIG(DISTINCT GovernorID) AS DistinctSourceValues,
        MIN(GovernorID) AS MinimumSourceValue,
        MAX(GovernorID) AS MaximumSourceValue
    FROM dbo.KingdomScanData4
    GROUP BY TRY_CONVERT(bigint, GovernorID)
)
SELECT
    N'governor_id_conversion_collisions' AS EvidenceSection,
    ConvertedGovernorId,
    DistinctSourceValues,
    MinimumSourceValue,
    MaximumSourceValue
FROM GovernorConversions
WHERE DistinctSourceValues > 1
ORDER BY ConvertedGovernorId
OPTION (MAXDOP 1);

SELECT
    N'string_contract_evidence' AS EvidenceSection,
    N'GovernorName' AS ColumnName,
    COUNT_BIG(*) AS [RowCount],
    SUM(CASE WHEN GovernorName IS NULL THEN CONVERT(bigint, 1) ELSE 0 END) AS NullCount,
    SUM(CASE WHEN GovernorName IS NOT NULL AND LEN(RTRIM(GovernorName)) = 0 THEN CONVERT(bigint, 1) ELSE 0 END) AS BlankCount,
    MAX(LEN(RTRIM(GovernorName))) AS MaximumTrimmedLength,
    SUM(CASE WHEN LEN(RTRIM(GovernorName)) > 100 THEN CONVERT(bigint, 1) ELSE 0 END) AS OverProposedLengthCount,
    SUM(CASE WHEN GovernorName IS NOT NULL AND GovernorName <> LTRIM(GovernorName) THEN CONVERT(bigint, 1) ELSE 0 END) AS LeadingSpaceCount,
    SUM(CASE WHEN GovernorName IS NOT NULL AND DATALENGTH(GovernorName) <> DATALENGTH(RTRIM(GovernorName)) THEN CONVERT(bigint, 1) ELSE 0 END) AS PaddedOrTrailingSpaceCount
FROM dbo.KingdomScanData4
UNION ALL
SELECT
    N'string_contract_evidence',
    N'Alliance',
    COUNT_BIG(*),
    SUM(CASE WHEN Alliance IS NULL THEN CONVERT(bigint, 1) ELSE 0 END),
    SUM(CASE WHEN Alliance IS NOT NULL AND LEN(RTRIM(Alliance)) = 0 THEN CONVERT(bigint, 1) ELSE 0 END),
    MAX(LEN(RTRIM(Alliance))),
    SUM(CASE WHEN LEN(RTRIM(Alliance)) > 50 THEN CONVERT(bigint, 1) ELSE 0 END),
    SUM(CASE WHEN Alliance IS NOT NULL AND Alliance <> LTRIM(Alliance) THEN CONVERT(bigint, 1) ELSE 0 END),
    SUM(CASE WHEN Alliance IS NOT NULL AND DATALENGTH(Alliance) <> DATALENGTH(RTRIM(Alliance)) THEN CONVERT(bigint, 1) ELSE 0 END)
FROM dbo.KingdomScanData4
OPTION (MAXDOP 1);

SELECT TOP (100)
    N'string_boundary_samples' AS EvidenceSection,
    N'GovernorName' AS ColumnName,
    GovernorName AS SourceValue,
    LEN(RTRIM(GovernorName)) AS TrimmedLength,
    DATALENGTH(GovernorName) AS StoredBytes
FROM dbo.KingdomScanData4
WHERE GovernorName IS NOT NULL
ORDER BY LEN(RTRIM(GovernorName)) DESC, GovernorName
OPTION (MAXDOP 1);

SELECT TOP (100)
    N'string_boundary_samples' AS EvidenceSection,
    N'Alliance' AS ColumnName,
    Alliance AS SourceValue,
    LEN(RTRIM(Alliance)) AS TrimmedLength,
    DATALENGTH(Alliance) AS StoredBytes
FROM dbo.KingdomScanData4
WHERE Alliance IS NOT NULL
ORDER BY LEN(RTRIM(Alliance)) DESC, Alliance
OPTION (MAXDOP 1);

SELECT
    N'pipeline_type_alignment' AS EvidenceSection,
    OBJECT_SCHEMA_NAME(c.object_id) AS SchemaName,
    OBJECT_NAME(c.object_id) AS ObjectName,
    c.column_id AS ColumnOrdinal,
    c.name AS ColumnName,
    ty.name AS DataType,
    c.max_length AS MaxLengthBytes,
    c.precision AS [Precision],
    c.scale AS Scale,
    c.is_nullable AS IsNullable
FROM sys.columns AS c
JOIN sys.types AS ty
  ON ty.user_type_id = c.user_type_id
WHERE c.object_id IN (
    OBJECT_ID(N'dbo.IMPORT_STAGING_CSV_RAW'),
    OBJECT_ID(N'dbo.IMPORT_STAGING_CSV'),
    OBJECT_ID(N'dbo.IMPORT_STAGING'),
    OBJECT_ID(N'dbo.KingdomScanData5'),
    OBJECT_ID(N'dbo.KingdomScanData4'),
    OBJECT_ID(N'dbo.STAGING_STATS'),
    OBJECT_ID(N'dbo.EXCEL_FOR_DASHBOARD'),
    OBJECT_ID(N'dbo.STATS_FOR_UPLOAD')
)
AND (
       c.name IN (
           N'Governor ID', N'GovernorID', N'Gov_ID', N'PowerRank', N'Rank',
           N'SCANORDER', N'Power', N'GovernorName', N'Governor_Name', N'Name',
           N'Alliance'
       )
    OR c.name LIKE N'%Kill%'
    OR c.name LIKE N'%Dead%'
    OR c.name LIKE N'%RSS%'
    OR c.name LIKE N'%Help%'
)
ORDER BY ObjectName, c.column_id;

SELECT
    N'as_of_date_contract' AS EvidenceSection,
    cc.name AS ColumnName,
    cc.definition AS ComputedDefinition,
    cc.is_persisted AS IsPersisted,
    ty.name AS DataType,
    cc.is_nullable AS IsNullable
FROM sys.computed_columns AS cc
JOIN sys.types AS ty
  ON ty.user_type_id = cc.user_type_id
WHERE cc.object_id = OBJECT_ID(N'dbo.KingdomScanData4')
  AND cc.name = N'AsOfDate';
