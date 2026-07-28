/*
KingdomScanData4 Phase 4 actual-plan and resource evidence.

Enable Include Actual Execution Plan in SSMS before running. STATISTICS XML,
IO, and TIME capture operators, estimates/actuals, grants, spills, warnings,
reads, CPU, and duration for the four changed views and the principal
vDaily_PlayerExport transitive consumer.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET STATISTICS XML ON;

SELECT *
INTO #Phase4PlanActivePlayers
FROM dbo.v_Active_Players;

SELECT *
INTO #Phase4PlanMgeSignupReview
FROM dbo.v_MGE_SignupReview;

SELECT *
INTO #Phase4PlanDailyPlayerExport
FROM dbo.vDaily_PlayerExport;

SELECT *
INTO #Phase4PlanGlobalLatest
FROM dbo.vw_Governor_KVK_Summary_GlobalLatest;

DECLARE @Latest datetime2(7) =
(
    SELECT MAX(AsOfDate)
    FROM dbo.vDaily_PlayerExport
);

SELECT *
INTO #Phase4PlanStatsWindow
FROM dbo.fn_StatsWindowDeltas
(
    DATEADD(DAY, -30, @Latest),
    @Latest
);

SET STATISTICS XML OFF;
SET STATISTICS TIME OFF;
SET STATISTICS IO OFF;

SELECT
    N'plan_materialization' AS EvidenceSection,
    (SELECT COUNT_BIG(*) FROM #Phase4PlanActivePlayers) AS ActivePlayerRows,
    (SELECT COUNT_BIG(*) FROM #Phase4PlanMgeSignupReview) AS MgeSignupReviewRows,
    (SELECT COUNT_BIG(*) FROM #Phase4PlanDailyPlayerExport) AS DailyPlayerExportRows,
    (SELECT COUNT_BIG(*) FROM #Phase4PlanGlobalLatest) AS GlobalLatestRows,
    (SELECT COUNT_BIG(*) FROM #Phase4PlanStatsWindow) AS StatsWindowRows,
    N'PASS' AS PlanCaptureStatus;
