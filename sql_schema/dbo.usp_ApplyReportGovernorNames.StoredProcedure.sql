SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_ApplyReportGovernorNames
    @Report sysname
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Report IS NULL OR @Report NOT IN (N'DEADSSUMMARY',N'POWERSUMMARY',N'KILLSUMMARY',N'KILL4SUMMARY',N'KILL5SUMMARY',N'KILLPOINTSSUMMARY',N'HEALEDSUMMARY',N'RANGEDSUMMARY',N'SUMMARY_CHANGE_EXPORT',N'POWER_BY_MONTH',N'ALL_GOVS',N'INACTIVE_GOVERNORS',N'EXCEL_FOR_DASHBOARD',N'DASH',N'ALL_STATS_FOR_DASHBAORD',N'STATS_FOR_UPLOAD',N'RALLY_EXPORT',N'CompletedReports')
        THROW 52970, 'Unknown report name target.', 1;
    -- Explicit targets only; names are applied AFTER numerical aggregation.
    -- Use the batch's single list, or resolve it once for a standalone caller.
    CREATE TABLE #P02LocalReportNames (
        GovernorID bigint NOT NULL PRIMARY KEY,
        GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NOT NULL
    );
    IF OBJECT_ID('tempdb..#P02ReportNames') IS NOT NULL
        INSERT #P02LocalReportNames SELECT GovernorID,GovernorName FROM #P02ReportNames;
    ELSE
        INSERT #P02LocalReportNames SELECT GovernorID,GovernorName FROM dbo.v_ReportGovernorNames;
    IF @Report IN (N'DEADSSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[DEADSSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'POWERSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[POWERSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'KILLSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILLSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'KILL4SUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILL4SUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'KILL5SUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILL5SUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'KILLPOINTSSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILLPOINTSSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'HEALEDSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[HEALEDSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'RANGEDSUMMARY',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[RANGEDSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'SUMMARY_CHANGE_EXPORT',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[SUMMARY_CHANGE_EXPORT] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'POWER_BY_MONTH',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[POWER_BY_MONTH] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'ALL_GOVS',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[ALL_GOVS] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'INACTIVE_GOVERNORS',N'CompletedReports')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[INACTIVE_GOVERNORS] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'EXCEL_FOR_DASHBOARD',N'CompletedReports')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[EXCEL_FOR_DASHBOARD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'DASH',N'CompletedReports')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[DASH] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'ALL_STATS_FOR_DASHBAORD',N'CompletedReports')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[ALL_STATS_FOR_DASHBAORD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'STATS_FOR_UPLOAD',N'CompletedReports')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[STATS_FOR_UPLOAD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N'RALLY_EXPORT',N'CompletedReports')
    BEGIN
        -- Both existing rally producers use "name (GovernorID)". Preserve rows
        -- without that exact suffix rather than guessing identity from a name.
        UPDATE r SET GOVENOR=CONCAT(n.GovernorName,N' (',CONVERT(varchar(20),n.GovernorID),N')')
        FROM dbo.RALLY_EXPORT r
        CROSS APPLY (SELECT CHARINDEX(N'(',REVERSE(RTRIM(r.GOVENOR))) AS OpeningFromEnd) p
        CROSS APPLY (SELECT TRY_CONVERT(bigint,SUBSTRING(RTRIM(r.GOVENOR),
            LEN(RTRIM(r.GOVENOR))-p.OpeningFromEnd+2,
            CASE WHEN p.OpeningFromEnd>=3 THEN p.OpeningFromEnd-2 ELSE 0 END)) AS GovernorID) g
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=g.GovernorID
        WHERE p.OpeningFromEnd>=3 AND RIGHT(RTRIM(r.GOVENOR),1)=N')'
          AND RIGHT(RTRIM(r.GOVENOR),p.OpeningFromEnd+1)
              =CONCAT(N' (',CONVERT(varchar(20),n.GovernorID),N')')
          AND RTRIM(r.GOVENOR) COLLATE Latin1_General_100_BIN2
              <> CONCAT(n.GovernorName,N' (',CONVERT(varchar(20),n.GovernorID),N')') COLLATE Latin1_General_100_BIN2;
    END;
END;
