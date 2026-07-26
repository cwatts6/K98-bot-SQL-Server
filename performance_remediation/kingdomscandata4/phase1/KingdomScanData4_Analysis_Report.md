# `KingdomScanData4` — Full Analysis & Recommendation Action Plan

> **Database:** `ROK_TRACKER` | **Server:** `MINI_AMD` (SQL Server 2022 Enterprise)
> **Table stats:** 394,506 rows | 2,371 distinct governors | 10 indexes | 33 dependent stored procedures and views
> **Report generated from live schema and DMV data.**

---

## Phase 1 evidence reconciliation — 2026-07-25

This document remains the external starting analysis, not an approved implementation
specification. Live collection and restored-copy testing refined several recommendations:

- all candidate numeric conversions are safe for the current 394,506 rows, with no fractional,
  failed, out-of-range or `GovernorID` collision evidence;
- `AsOfDate` is already a persisted computed `date` in the authoritative schema, so that proposed
  change is stale/already satisfied;
- the typed ingestion contract is locked at `nvarchar(200)` for names and `nvarchar(100)` for
  alliance/civilization; the narrower 100/50 proposal is rejected;
- no index is approved for removal solely from the short post-restart DMV window; final index
  changes require named workload and before/after plan evidence;
- controlled baselines are stable, and all restored-copy `UPDATE_ALL2` functional scenarios
  passed, including invalid/retry, Phase-B rollback and simultaneous concurrency;
- historical `float` risk is established, but no prior value corruption has been proven.

Phase 1 and all five formal gate items are complete. Shadow-copy forward and production-usable
rollback passed against the same representative-copy run ID with exact digests and no snapshot.
See `audit_report.md`, `benchmark_manifest.md`, `closure_matrix.md` and
`phase2_approval_checkpoint.md`. Phase 2 still requires explicit operator approval; do not execute
the example DDL below as an approved migration.

## Table of Contents

1. [Issue Category 1 — Wrong Data Types (Float Columns)](#issue-category-1--wrong-data-types-float-columns)
2. [Issue Category 2 — nchar String Columns](#issue-category-2--nchar-string-columns)
3. [Issue Category 3 — AsOfDate Computed Column Not Persisted](#issue-category-3--asofdate-computed-column-not-persisted)
4. [Issue Category 4 — Index Redundancy and Dead Weight](#issue-category-4--index-redundancy-and-dead-weight)
5. [Issue Category 5 — Stored Procedure Anti-Patterns](#issue-category-5--stored-procedure-anti-patterns-caused-by-wrong-types)
6. [Recommended Action Plan](#recommended-action-plan)
7. [Impact Summary](#impact-summary)

---

## Issue Category 1 — Wrong Data Types (Float Columns)

### Root Cause

The table was almost certainly created by importing from Excel or a staging table that mapped all numeric values to `float`. **Zero rows** in the entire 394,506-row dataset have any decimal value in any of these columns — they are all whole integers stored in 8-byte floating-point fields.

### Impact of `float`

- **Implicit conversion overhead on every query and join.** Every stored procedure does `CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID)` — this fires 394,000+ times per execution of each summary proc.
- **Index key bloat.** Float keys are 8 bytes; `INT` is 4 bytes. Reducing key size improves index density and fit-in-memory.
- **Precision risk.** Floats cannot represent all large integers exactly. Values with more than ~15 significant digits suffer rounding.
- **Sort/compare instability.** Float comparisons use approximate equality, which is incorrect for ID lookups and range filters.

### Column-by-Column Verdict

| Column | Current Type | Recommended Type | Reason |
|---|---|---|---|
| `GovernorID` | `float` | `BIGINT` | Max 228M, zero decimals. Used as FK/join key in every proc and view. |
| `PowerRank` | `float` | `INT` | Ranking integer 1-N. No decimals. |
| `SCANORDER` | `float` | `INT` | Sequential scan counter. Used as range filter in every summary proc. |
| `Power` | `float` | `BIGINT` | Max 161M, fits INT today but grows over time. |
| `KillPoints` | `float` | `BIGINT` | Max **11,033,630,206** — exceeds INT range (2,147,483,647). Currently losing precision. |
| `Deads` | `float` | `BIGINT` | Whole numbers only. |
| `T1_Kills` through `T5_Kills` | `float` | `BIGINT` | T5 max 447M, safe in INT today but BIGINT is correct for all kill columns. |
| `T4&T5_KILLS` | `float` | `BIGINT` | Derived sum. Nullable. |
| `TOTAL_KILLS` | `float` | `BIGINT` | Max **3,236,103,125** — exceeds INT range. |
| `RSS_Gathered` | `float` | `BIGINT` | Max **78,717,370,555** — far beyond INT range. |
| `RSSAssistance` | `float` | `BIGINT` | Max **61,525,643,225** — far beyond INT range. |
| `Helps` | `float` | `BIGINT` | Whole numbers only. |

> **`KillPoints`, `TOTAL_KILLS`, `RSS_Gathered`, and `RSSAssistance` are currently storing values that `float` cannot represent exactly.** Precision errors are silent — the data looks plausible but can be off by 1-2 units at large values.

---

## Issue Category 2 — nchar String Columns

### Root Cause

`GovernorName` and `Alliance` are declared as `nchar(255)` (max_length = 510 bytes in sys.columns). `nchar` is **fixed-length** — every row is padded with spaces to the full 255 characters regardless of actual content.

### Actual Data vs Declared Size

| Column | Declared Length | Max Actual Length (measured) | Wasted bytes per row |
|---|---|---|---|
| `GovernorName` | `nchar(255)` = 510 bytes | **67 chars** (134 bytes) | ~376 bytes of spaces |
| `Alliance` | `nchar(255)` = 510 bytes | **26 chars** (52 bytes) | ~458 bytes of spaces |

### Impact

- **Every index that includes these columns carries the full 510-byte fixed allocation per row**, inflating every NCI that touches `GovernorName` or `Alliance` — and 7 of the 10 indexes do.
- **Forces mandatory `RTRIM()` throughout every stored procedure and view** because `nchar` pads outputs with trailing spaces. Without `RTRIM`, comparisons against `nvarchar` parameters and string outputs are incorrect.
- Examples from the codebase:
  - `v_GovernorNames`: `NULLIF(LTRIM(RTRIM(L.GovernorName)), '')`
  - `UPDATE_ALL2`: `RTRIM(COALESCE(ed.[Governor_Name], ''))`
  - `IMPORT_STAGING_PROC`: `RTRIM(ISNULL([Name], ''))`
  - `vDaily_PlayerExport`: `MAX(LTRIM(RTRIM(ks.GovernorName)))`

### Recommendation

```
GovernorName : nchar(255)  ->  nvarchar(100)   (67 char max + comfortable buffer)
Alliance     : nchar(255)  ->  nvarchar(50)    (26 char max + comfortable buffer)
```

---

## Issue Category 3 — AsOfDate Computed Column Not Persisted

`AsOfDate` is defined as `(CONVERT([date],[ScanDate]))` — a non-persisted computed column. The index `IX_KS4_AsOf_Governor` is built on it (which SQL Server permits for deterministic expressions), but without `PERSISTED`, the value is **recomputed for every row accessed** during scans.

**Recommendation:** Add `PERSISTED` — stores the computed value physically, eliminates per-row recalculation, and reduces overhead on the `AsOfDate` index.

---

## Issue Category 4 — Index Redundancy and Dead Weight

The table has **10 indexes** but only ever receives inserts (never updates to existing rows). Every new scan batch pays the cost of maintaining all 10 indexes simultaneously.

### Dead Indexes — Drop Immediately

| Index | Keys | Seeks | Scans | Verdict |
|---|---|---|---|---|
| `IX_KingdomScanData4_GovernorID_ScanOrder` | `GovernorID, SCANORDER` INCLUDE `ScanDate, GovernorName, PowerRank, Deads, HealedTroops` | **0** | **0** | DROP — completely unused; fully shadowed by `IX_KSD4_Gov_ScanOrder` |
| `IX_KS4_Governor_ScanDate_ScanOrder` | `GovernorID, ScanDate, SCANORDER` INCLUDE `Deads, GovernorName, PowerRank` | **0** | **0** | DROP — completely unused; pattern superseded by `IX_KS4_AsOf_Governor` |

### Near-Dead Indexes — Consolidate

| Index | Keys | Seeks | Scans | Verdict |
|---|---|---|---|---|
| `IX_KingdomScanData4_GovernorID_ScanOrder_Covering` | `GovernorID, SCANORDER` INCLUDE many columns | **6** | **0** | DROP — same key prefix as `IX_KSD4_Gov_ScanOrder`; expand that index's includes instead |
| `IX_KSD4_Governor_ScanOrder` | `GovernorID, SCANORDER DESC, AsOfDate DESC, ScanDate DESC` INCLUDE `GovernorName, Alliance` | **3** | **0** | Consolidate — barely used; serves `v_GovernorNames` latest-per-governor pattern; replace with a dedicated lookup index |
| `IX_KS4_Governor_ScanDate` | `GovernorID, ScanDate` INCLUDE `Power, KillPoints, T4&T5_KILLS, Deads, GovernorName` | **6** | **0** | Drop after `IX_KS4_AsOf_Governor` INCLUDE expansion |
| `IX_kingdomscandata4_ScanOrder_DESC` | `SCANORDER DESC` | **58** | **114** | Merge — single column only; consolidate into a new `SCANORDER DESC` leading index that also covers `GovernorID` |

### Healthy Indexes — Keep and Refine

| Index | Keys | Seeks | Scans | Notes |
|---|---|---|---|---|
| `CIX_KS4_ScanOrder_Governor` | `SCANORDER, GovernorID` (CLUSTERED) | 347 | 1,090 | Good for append pattern. Serves `WHERE SCANORDER > @n` range scans via the CIX. |
| `IX_KSD4_Gov_ScanOrder` | `GovernorID, SCANORDER` INCLUDE `PowerRank, ScanDate` | **652** | **666** | Most-used NCI. Expand includes to cover summary proc column needs. |
| `IX_KS4_AsOf_Governor` | `AsOfDate, GovernorID` INCLUDE many | 325 | 82 | Well-used for daily delta views. |
| `IX_KingdomScanData4_ScanOrder_GovernorID` | `SCANORDER, GovernorID` INCLUDE `ScanDate, GovernorName, PowerRank, Deads, HealedTroops` | 161 | 159 | Keep — serves latest-scan snapshot queries. |

### Net Index Count After Phase 2

| Before | After | Saving |
|---|---|---|
| 10 indexes | 5 indexes | 50% fewer indexes to maintain per insert |

---

## Issue Category 5 — Stored Procedure Anti-Patterns (Caused by Wrong Types)

### Pattern 1: `CROSS APPLY TRY_CONVERT` on `GovernorID` (present in all 9 summary procs)

`DEADSSUMMARY_PROC`, `HEALEDSUMMARY_PROC`, `HEALEDSUMMARY_PROC_OPT`, `KILLPOINTSSUMMARY_PROC`, `KILLSSUMMARY_PROC`, `KT4SUMMARY_PROC`, `KT5SUMMARY_PROC`, `POWERSUMMARY_PROC`, `RANGEDSUMMARY_PROC`, `SUMMARY_PROC` all contain:

```sql
-- Fires once per row in the filtered result set — up to 394K conversions per proc run
CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
WHERE ks4.ScanOrder > @LastProcessed
  AND conv.GovernorID IS NOT NULL
  AND conv.GovernorID <> 0;
```

This exists solely because `GovernorID` is `float`. After the type fix it is removed entirely.

### Pattern 2: `FLOAT` State Variables (all summary procs)

```sql
DECLARE @LastProcessed FLOAT = 0;  -- should be INT
DECLARE @MaxScan FLOAT = 0;        -- should be INT
```

Comparing an `INT` column (`SCANORDER` after fix) against a `FLOAT` variable reintroduces an implicit conversion on the column, **preventing index seeks** on the CIX and `IX_KSD4_Gov_ScanOrder`.

### Pattern 3: `TRY_CONVERT` Wrapping in `vDaily_PlayerExport`

```sql
-- Every column in the CTE is wrapped because source columns were float
MAX(TRY_CONVERT(bigint, ks.Power))           AS Power,
MAX(TRY_CONVERT(bigint, ks.KillPoints))      AS KillPoints,
MAX(TRY_CONVERT(bigint, ks.Deads))           AS Deads,
-- ... repeated for every numeric column
```

After the type fix, all of these become direct column references.

### Pattern 4: `CAST(GovernorID AS bigint)` in Views

- `v_Active_Players`: `CAST(KS4.[GovernorID] AS bigint) AS [GovernorID]`
- `vw_Governor_KVK_Summary_GlobalLatest`: `CAST(ls.GovernorID AS BIGINT)` and `CAST(ls.GovernorID AS BIGINT)` in JOIN predicates

### Pattern 5: `Refresh_PlayerScanMeta` Uses `float` for `GovernorID`

```sql
CREATE TABLE #Governors (GovernorID float NOT NULL PRIMARY KEY);
-- and parameters:
@StartingGovernorID float = NULL,
@MinScanOrder float = NULL
```

Joins from `#Governors` back to `KingdomScanData4` on `GovernorID` will produce an implicit conversion on the table column after the type fix, negating the index improvement.

---

## Recommended Action Plan

> **This is the original preliminary action plan, not current execution authority.** All DDL
> changes require a maintenance window. Do not begin the data-type DDL described below until the
> formal evidence gate listed in the reconciliation section is closed and the exact forward and
> rollback design has been approved. Any `ALTER COLUMN` plan must be rehearsed because it can
> rewrite the table and rebuild dependent indexes.

---

### Phase 1 — Correct Data Types

```sql
-- ============================================================
-- PHASE 1: Data Type Corrections for dbo.KingdomScanData4
-- ============================================================

-- Step 1a: Drop indexes that depend on columns being altered,
--          and the computed AsOfDate column (depends on ScanDate).
--          Also drop dead/redundant indexes now to reduce rebuild cost.

DROP INDEX IF EXISTS [IX_KingdomScanData4_GovernorID_ScanOrder]          ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KS4_Governor_ScanDate_ScanOrder]                ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KingdomScanData4_GovernorID_ScanOrder_Covering] ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KSD4_Governor_ScanOrder]                        ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KS4_Governor_ScanDate]                          ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_kingdomscandata4_ScanOrder_DESC]                ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KSD4_Gov_ScanOrder]                             ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KingdomScanData4_ScanOrder_GovernorID]          ON dbo.KingdomScanData4;
DROP INDEX IF EXISTS [IX_KS4_AsOf_Governor]                              ON dbo.KingdomScanData4;

-- Step 1b: Drop the computed column
--          (required before altering ScanDate, and before rebuilding as PERSISTED).
ALTER TABLE dbo.KingdomScanData4 DROP COLUMN AsOfDate;

-- Step 1c: Alter all float -> integer columns.
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN GovernorID    BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN PowerRank     INT    NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN SCANORDER     INT    NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN Power         BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN KillPoints    BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN Deads         BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN T1_Kills      BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN T2_Kills      BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN T3_Kills      BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN T4_Kills      BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN T5_Kills      BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN [T4&T5_KILLS] BIGINT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN TOTAL_KILLS   BIGINT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN RSS_Gathered  BIGINT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN RSSAssistance BIGINT NOT NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN Helps         BIGINT NOT NULL;

-- Step 1d: Fix nchar -> nvarchar string columns.
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN GovernorName  NVARCHAR(100) NULL;
ALTER TABLE dbo.KingdomScanData4 ALTER COLUMN Alliance      NVARCHAR(50)  NULL;

-- Step 1e: Re-add AsOfDate as a PERSISTED computed column.
ALTER TABLE dbo.KingdomScanData4
	ADD AsOfDate AS CONVERT(date, ScanDate) PERSISTED;
```

---

### Phase 2 — Rebuild Indexes (Consolidated & Correct)

```sql
-- ============================================================
-- PHASE 2: Consolidated Index Rebuild for dbo.KingdomScanData4
-- Net result: 10 indexes -> 5 indexes
-- ============================================================

-- NOTE: CIX_KS4_ScanOrder_Governor is rebuilt automatically by SQL Server
-- during the ALTER COLUMN table rewrite in Phase 1. Verify it exists after Phase 1.

-- INDEX 2: Primary governor lookup.
-- Replaces: IX_KSD4_Gov_ScanOrder, IX_KingdomScanData4_GovernorID_ScanOrder,
--           IX_KingdomScanData4_GovernorID_ScanOrder_Covering.
-- Covers all summary proc patterns:
--   WHERE GovernorID = @n
--   WHERE GovernorID = @n AND SCANORDER > @m
CREATE NONCLUSTERED INDEX [IX_KS4_Gov_ScanOrder_Covering]
	ON dbo.KingdomScanData4 (GovernorID ASC, SCANORDER ASC)
	INCLUDE (
		PowerRank, ScanDate, AsOfDate, GovernorName, Alliance,
		Power, KillPoints, Deads, HealedTroops, RangedPoints,
		T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS,
		RSSAssistance, RSS_Gathered, Helps
	);

-- INDEX 3: Latest scan + governor lookup.
-- Replaces: IX_KingdomScanData4_ScanOrder_GovernorID + IX_kingdomscandata4_ScanOrder_DESC.
-- Serves all patterns:
--   WHERE SCANORDER = (SELECT MAX(SCANORDER) ...)
--   SELECT MAX(SCANORDER) FROM KingdomScanData4
CREATE NONCLUSTERED INDEX [IX_KS4_ScanOrder_Gov_Covering]
	ON dbo.KingdomScanData4 (SCANORDER DESC, GovernorID ASC)
	INCLUDE (
		PowerRank, GovernorName, Alliance, ScanDate, AsOfDate,
		Power, KillPoints, Deads, HealedTroops
	);

-- INDEX 4: Governor latest-row lookup.
-- Replaces: IX_KSD4_Governor_ScanOrder.
-- Serves v_GovernorNames OUTER APPLY pattern:
--   ORDER BY SCANORDER DESC, AsOfDate DESC, ScanDate DESC
CREATE NONCLUSTERED INDEX [IX_KS4_Gov_LatestLookup]
	ON dbo.KingdomScanData4 (GovernorID ASC, SCANORDER DESC)
	INCLUDE (GovernorName, Alliance, AsOfDate, ScanDate);

-- INDEX 5: Daily delta view pattern.
-- Replaces: IX_KS4_AsOf_Governor (rebuilt after PERSISTED column re-add).
-- Serves vDaily_*, vWTD_* views.
CREATE NONCLUSTERED INDEX [IX_KS4_AsOf_Governor]
	ON dbo.KingdomScanData4 (AsOfDate ASC, GovernorID ASC)
	INCLUDE (
		Power, KillPoints, TOTAL_KILLS, Deads, Helps,
		RSS_Gathered, RSSAssistance, GovernorName,
		T4_Kills, T5_Kills, [T4&T5_KILLS], HealedTroops, RangedPoints
	);
```

---

### Phase 3 — Update Stored Procedures

> Apply all changes below after Phase 1 is deployed. The `TRY_CONVERT` wrappers are safe against the new types — leaving them in place temporarily will not break anything. Remove them in a coordinated deployment.

---

#### 3a — All Summary Procs

Applies to: `DEADSSUMMARY_PROC`, `HEALEDSUMMARY_PROC`, `HEALEDSUMMARY_PROC_OPT`, `KILLPOINTSSUMMARY_PROC`, `KILLSSUMMARY_PROC`, `KT4SUMMARY_PROC`, `KT5SUMMARY_PROC`, `POWERSUMMARY_PROC`, `RANGEDSUMMARY_PROC`, `SUMMARY_PROC`.

**Change 1 — Fix state variable types (in every proc)**

```sql
-- BEFORE
DECLARE @LastProcessed FLOAT = 0;
DECLARE @MaxScan FLOAT = 0;

-- AFTER
DECLARE @LastProcessed INT = 0;
DECLARE @MaxScan INT = 0;
```

**Change 2 — Remove `CROSS APPLY TRY_CONVERT` for `#AffectedGovs` population (in every proc)**

```sql
-- BEFORE
INSERT INTO #AffectedGovs (GovernorID)
SELECT DISTINCT conv.GovernorID
FROM dbo.KingdomScanData4 ks4
CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
WHERE ks4.ScanOrder > @LastProcessed
  AND conv.GovernorID IS NOT NULL
  AND conv.GovernorID <> 0;

-- AFTER
INSERT INTO #AffectedGovs (GovernorID)
SELECT DISTINCT ks4.GovernorID
FROM dbo.KingdomScanData4 ks4
WHERE ks4.SCANORDER > @LastProcessed
  AND ks4.GovernorID IS NOT NULL
  AND ks4.GovernorID <> 0;
```

**Change 3 — Remove `CROSS APPLY TRY_CONVERT` for `#GovScan` population (in every proc)**

```sql
-- BEFORE (DEADSSUMMARY_PROC example — same pattern in all procs)
SELECT
	conv.GovernorID AS GovernorID,
	ks4.GovernorName,
	ks4.PowerRank,
	ks4.ScanOrder,
	ks4.ScanDate,
	ks4.Deads        -- swap for the relevant metric column per proc
INTO #GovScan
FROM dbo.KingdomScanData4 ks4
CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
INNER JOIN #AffectedGovs a ON a.GovernorID = conv.GovernorID;

-- AFTER
SELECT
	ks4.GovernorID,
	ks4.GovernorName,
	ks4.PowerRank,
	ks4.SCANORDER,
	ks4.ScanDate,
	ks4.Deads        -- swap for the relevant metric column per proc
INTO #GovScan
FROM dbo.KingdomScanData4 ks4
INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;
```

**Change 4 — Update `#SummaryRunState` column types in `SUMMARY_PROC`**

```sql
-- BEFORE
CREATE TABLE #SummaryRunState
(
	MaxScan          FLOAT NOT NULL,
	MinLastProcessed FLOAT NOT NULL
);

-- AFTER
CREATE TABLE #SummaryRunState
(
	MaxScan          INT NOT NULL,
	MinLastProcessed INT NOT NULL
);
```

---

#### 3b — `HEALEDSUMMARY_PROC_OPT` — Additional Explicit `#GovScan` Fix

```sql
-- BEFORE (explicit CREATE TABLE for #GovScan with legacy types)
CREATE TABLE #GovScan
(
	GovernorID   BIGINT        NOT NULL,
	GovernorName NVARCHAR(400) NULL,       -- oversized for nchar(255) source
	PowerRank    INT           NULL,
	ScanOrder    FLOAT         NOT NULL,   -- float
	ScanDate     DATETIME      NULL,
	HealedTroops BIGINT        NULL
);

INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
SELECT
	conv.GovernorID,
	CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,  -- CONVERT needed for nchar
	TRY_CONVERT(INT, ks4.PowerRank)          AS PowerRank,     -- TRY_CONVERT for float
	ks4.ScanOrder,
	ks4.ScanDate,
	ks4.HealedTroops
FROM dbo.KingdomScanData4 ks4
CROSS APPLY (SELECT TRY_CONVERT(BIGINT, ks4.GovernorID) AS GovernorID) conv
INNER JOIN #AffectedGovs a ON a.GovernorID = conv.GovernorID;

-- AFTER
CREATE TABLE #GovScan
(
	GovernorID   BIGINT        NOT NULL,
	GovernorName NVARCHAR(100) NULL,   -- matches new column type
	PowerRank    INT           NULL,
	ScanOrder    INT           NOT NULL, -- matches new SCANORDER type
	ScanDate     DATETIME      NULL,
	HealedTroops BIGINT        NULL
);

INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
SELECT
	ks4.GovernorID,
	ks4.GovernorName,    -- nvarchar, no CONVERT needed
	ks4.PowerRank,       -- INT, no TRY_CONVERT needed
	ks4.SCANORDER,
	ks4.ScanDate,
	ks4.HealedTroops
FROM dbo.KingdomScanData4 ks4
INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;
```

---

#### 3c — `Refresh_PlayerScanMeta`

```sql
-- BEFORE (parameters and temp table use float)
ALTER PROCEDURE [dbo].[Refresh_PlayerScanMeta]
	@FullRebuild        BIT   = 0,
	@MinScanOrder       FLOAT = NULL,   -- float
	@FromScanDate       DATE  = NULL,
	@BatchSize          INT   = NULL,
	@StartingGovernorID FLOAT = NULL    -- float

-- Temp table:
CREATE TABLE #Governors (GovernorID FLOAT NOT NULL PRIMARY KEY);
DECLARE @LastGovernorID FLOAT = ISNULL(@StartingGovernorID, 0);

-- AFTER
ALTER PROCEDURE [dbo].[Refresh_PlayerScanMeta]
	@FullRebuild        BIT    = 0,
	@MinScanOrder       INT    = NULL,   -- matches SCANORDER INT
	@FromScanDate       DATE   = NULL,
	@BatchSize          INT    = NULL,
	@StartingGovernorID BIGINT = NULL    -- matches GovernorID BIGINT

-- Temp table:
CREATE TABLE #Governors (GovernorID BIGINT NOT NULL PRIMARY KEY);
DECLARE @LastGovernorID BIGINT = ISNULL(@StartingGovernorID, 0);
```

---

#### 3d — `FIX_IMPORT_STAGING` and Staging Table

No SQL change is required to the `SCANORDER` update statement itself — `MAX(SCANORDER) + 1` will naturally return `INT` after the type fix. However, verify that all staging table columns are aligned:

```sql
-- Ensure staging table column types match the corrected source table:
ALTER TABLE dbo.IMPORT_STAGING ALTER COLUMN SCANORDER   INT    NOT NULL;
ALTER TABLE dbo.IMPORT_STAGING ALTER COLUMN [Governor ID] BIGINT NOT NULL;
-- (verify all other numeric columns in IMPORT_STAGING align with KingdomScanData4)
```

---

### Phase 4 — Update Views

---

#### `v_Active_Players`

```sql
-- BEFORE
CAST(KS4.[GovernorID] AS bigint) AS [GovernorID],  -- cast needed because source was float

-- AFTER (GovernorID is now BIGINT natively)
KS4.[GovernorID] AS [GovernorID],
```

---

#### `vDaily_PlayerExport`

```sql
-- BEFORE — every numeric column in the KSDay CTE is wrapped in TRY_CONVERT
MAX(TRY_CONVERT(bigint, ks.Power))           AS Power,
MAX(TRY_CONVERT(bigint, ks.[Troops Power]))  AS TroopPower,
MAX(TRY_CONVERT(bigint, ks.KillPoints))      AS KillPoints,
MAX(TRY_CONVERT(bigint, ks.Deads))           AS Deads,
MAX(TRY_CONVERT(bigint, ks.RSS_Gathered))    AS RSS_Gathered,
MAX(TRY_CONVERT(bigint, ks.RSSAssistance))   AS RSSAssist,
MAX(TRY_CONVERT(bigint, ks.Helps))           AS Helps,
MAX(TRY_CONVERT(bigint, ks.[Tech Power]))    AS TechPower,
MAX(TRY_CONVERT(bigint, ks.T4_Kills))        AS T4_Kills,
MAX(TRY_CONVERT(bigint, ks.T5_Kills))        AS T5_Kills,
MAX(TRY_CONVERT(bigint, ks.[T4&T5_KILLS]))   AS T4T5_Kills,
MAX(TRY_CONVERT(bigint, ks.HealedTroops))    AS HealedTroops,
MAX(TRY_CONVERT(bigint, ks.RangedPoints))    AS RangedPoints,
MAX(TRY_CONVERT(bigint, ks.HighestAcclaim))  AS HighestAcclaim,
MAX(TRY_CONVERT(int,    ks.AOOJoined))       AS AOOJoined,
MAX(TRY_CONVERT(int,    ks.AOOWon))          AS AOOWon,
MAX(TRY_CONVERT(int,    ks.AutarchTimes))    AS AutarchTimes,

-- AFTER — direct aggregation, no conversion needed
MAX(ks.Power)            AS Power,
MAX(ks.[Troops Power])   AS TroopPower,
MAX(ks.KillPoints)       AS KillPoints,
MAX(ks.Deads)            AS Deads,
MAX(ks.RSS_Gathered)     AS RSS_Gathered,
MAX(ks.RSSAssistance)    AS RSSAssist,
MAX(ks.Helps)            AS Helps,
MAX(ks.[Tech Power])     AS TechPower,
MAX(ks.T4_Kills)         AS T4_Kills,
MAX(ks.T5_Kills)         AS T5_Kills,
MAX(ks.[T4&T5_KILLS])    AS T4T5_Kills,
MAX(ks.HealedTroops)     AS HealedTroops,
MAX(ks.RangedPoints)     AS RangedPoints,
MAX(ks.HighestAcclaim)   AS HighestAcclaim,
MAX(ks.AOOJoined)        AS AOOJoined,
MAX(ks.AOOWon)           AS AOOWon,
MAX(ks.AutarchTimes)     AS AutarchTimes,
```

> **Note:** The `TRY_CONVERT` wrappers on **delta calculations** in the `KSDeltas` CTE (e.g. `TRY_CONVERT(bigint, d.Power - LAG(d.Power) OVER (...))`) are acceptable to keep — subtraction of two `BIGINT` values could overflow and `TRY_CONVERT` provides a safe guard. Alternatively, replace with explicit `CASE WHEN` overflow protection.

---

#### `v_GovernorNames`

```sql
-- BEFORE (LTRIM/RTRIM required because nchar pads with spaces)
WHERE k.GovernorName IS NOT NULL
  AND LTRIM(RTRIM(k.GovernorName)) <> ''

-- AFTER (nvarchar does not pad — empty-string check is now accurate without RTRIM)
WHERE k.GovernorName IS NOT NULL
  AND k.GovernorName <> ''
-- LTRIM/RTRIM on output display strings remain fine for defensive trimming.
```

---

#### `vw_Governor_KVK_Summary_GlobalLatest`

```sql
-- BEFORE
CAST(ls.GovernorID AS BIGINT)           AS [GovernorId],
LEFT JOIN kvk_latest ON kvk_latest.Gov_ID = CAST(ls.GovernorID AS BIGINT)
LEFT JOIN kvk_prev   ON kvk_prev.Gov_ID   = CAST(ls.GovernorID AS BIGINT)

-- AFTER (GovernorID is now BIGINT natively)
ls.GovernorID                           AS [GovernorId],
LEFT JOIN kvk_latest ON kvk_latest.Gov_ID = ls.GovernorID
LEFT JOIN kvk_prev   ON kvk_prev.Gov_ID   = ls.GovernorID
-- Also verify EXCEL_FOR_DASHBOARD.Gov_ID is BIGINT to avoid implicit conversion on join.
```

---

## Impact Summary

| Issue | Severity | Performance Impact | Risk if Not Fixed |
|---|---|---|---|
| `GovernorID` stored as `float` | Critical | `TRY_CONVERT` on every row in 8+ procs x every execution; prevents SARGable seeks | Join mismatches possible; 394K conversions per proc run |
| `KillPoints`, `TOTAL_KILLS`, `RSS_Gathered`, `RSSAssistance` as `float` | Critical | Silent precision loss at large values | **Data is currently imprecise** — values above float precision limit (~15 significant digits) are silently rounded |
| `SCANORDER` as `float` | High | Float comparisons on every range filter; `FLOAT` variables cause implicit conversion on the column, blocking index seeks | Potential rounding errors at scan boundary comparisons |
| `GovernorName` / `Alliance` as `nchar(255)` | High | 376-458 bytes wasted per row in every index that includes these columns (7 of 10 do); mandatory `RTRIM` throughout all procs and views | Index bloat; incorrect string comparisons without `RTRIM` |
| 2 completely unused indexes | High | Every scan batch insert maintains 2 indexes with zero reads | Wasted write I/O and lock contention on every import |
| 3 near-dead redundant indexes | Medium | Duplicate maintenance cost on every insert | Memory and disk waste; optimizer confusion with overlapping statistics |
| `AsOfDate` computed column not `PERSISTED` | Medium | Recomputed per-row during every table/index scan on the daily delta views | Extra CPU cost on all `vDaily_*` and `vWTD_*` queries |
| `TRY_CONVERT` wrappers in procs and views after type fix | Medium | Unnecessary function evaluation on every row; prevents SARGable predicate pushdown | After Phase 1, leaving them in is harmless but wastes CPU |
| `Refresh_PlayerScanMeta` using `float` GovernorID parameter and `#Governors` temp table | Medium | After Phase 1, the `float` join to the `BIGINT` column reintroduces implicit conversions, negating the type fix | Partial improvement only if not updated alongside Phase 1 |

---

*Report produced by GitHub Copilot — SQL Server Management Studio 22 | ROK_TRACKER on MINI_AMD (SQL Server 2022 Enterprise)*
