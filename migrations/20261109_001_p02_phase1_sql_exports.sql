/*
MigrationId: 20261109_001_p02_phase1_sql_exports
Purpose: Install qualified summaries, shared latest names and exact numeric outputs
Author: Codex (operator-approved implementation; production approval separate)
CreatedUtc: 2026-11-09
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Required
DataChange: Yes
DataSafetyPlan: Included
DataSafetyNotes: Coordinated runner owns one transaction, exact pre/post images, range checks and backup/resource gates. Failure before commit rolls back. After commit preserve evidence and complete the same release forward; no automatic downgrade, restore or replay.
EstimatedRowsAffected: Existing rows in the 31 explicitly reviewed output tables
*/
-- Fixed Phase 1 forward candidate. Use only through the reviewed coordinated release runner.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 52980,'Phase 1 release-owned transaction required.',1;
IF DB_NAME()<>N'ROK_TRACKER' THROW 52980,'Exact Phase 1 production database required.',1;
DECLARE @locked_rows bigint;
DECLARE @tables TABLE(name sysname PRIMARY KEY);
INSERT @tables(name) VALUES (N'dbo.D12D'),(N'dbo.D3D'),(N'dbo.D6D'),(N'dbo.DEADSSUMMARY'),(N'dbo.K12D'),(N'dbo.K3D'),(N'dbo.K412D'),(N'dbo.K43D'),(N'dbo.K46D'),(N'dbo.K512D'),(N'dbo.K53D'),(N'dbo.K56D'),(N'dbo.K6D'),(N'dbo.KILL4SUMMARY'),(N'dbo.KILL5SUMMARY'),(N'dbo.KILLPOINTSSUMMARY'),(N'dbo.KILLPOINTS_D12D'),(N'dbo.KILLPOINTS_D3D'),(N'dbo.KILLPOINTS_D6D'),(N'dbo.KILLPOINTS_LATEST'),(N'dbo.KILLSUMMARY'),(N'dbo.LATEST'),(N'dbo.LATEST_POWER'),(N'dbo.LATEST_T4&T5_KILLS'),(N'dbo.LATEST_T4_KILLS'),(N'dbo.LATEST_T5_KILLS'),(N'dbo.P12D'),(N'dbo.P3D'),(N'dbo.P6D'),(N'dbo.POWERSUMMARY'),(N'dbo.SUMMARY_CHANGE_EXPORT');
IF EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.data_spaces ds ON ds.data_space_id=i.data_space_id
 JOIN sys.stats s ON s.object_id=i.object_id AND s.stats_id=i.index_id
 WHERE i.object_id IN(SELECT OBJECT_ID(name) FROM @tables) AND i.index_id>0
 AND (i.fill_factor<>0 OR i.is_padded<>0 OR i.ignore_dup_key<>0 OR i.allow_row_locks<>1
 OR i.allow_page_locks<>1 OR i.optimize_for_sequential_key<>0 OR s.no_recompute<>0 OR ds.name<>N'PRIMARY'))
 THROW 52980,'Unreviewed Phase 1 index or statistics options.',1;
IF EXISTS(SELECT 1 FROM sys.partitions WHERE object_id IN(SELECT OBJECT_ID(name) FROM @tables)
 AND (partition_number<>1 OR data_compression<>0)) THROW 52980,'Unreviewed Phase 1 partition/compression.',1;
IF EXISTS(SELECT 1 FROM sys.stats WHERE object_id IN(SELECT OBJECT_ID(name) FROM @tables)
 AND user_created=1 AND stats_id NOT IN(SELECT index_id FROM sys.indexes WHERE object_id=sys.stats.object_id))
 THROW 52980,'Standalone user statistics require separate preservation.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[D12D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[D12D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([DEADSDelta12Months] IS NOT NULL AND ([DEADSDelta12Months]<>FLOOR([DEADSDelta12Months]) OR TRY_CONVERT(bigint,[DEADSDelta12Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.D12D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[D3D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[D3D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([DEADSDelta3Months] IS NOT NULL AND ([DEADSDelta3Months]<>FLOOR([DEADSDelta3Months]) OR TRY_CONVERT(bigint,[DEADSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.D3D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[D6D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[D6D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([DEADSDelta6Months] IS NOT NULL AND ([DEADSDelta6Months]<>FLOOR([DEADSDelta6Months]) OR TRY_CONVERT(bigint,[DEADSDelta6Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.D6D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[DEADSSUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[DEADSSUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([PowerRank] IS NOT NULL AND ([PowerRank]<>FLOOR([PowerRank]) OR TRY_CONVERT(int,[PowerRank]) IS NULL)) OR ([DEADS] IS NOT NULL AND ([DEADS]<>FLOOR([DEADS]) OR TRY_CONVERT(bigint,[DEADS]) IS NULL)) OR ([StartingDEADS] IS NOT NULL AND ([StartingDEADS]<>FLOOR([StartingDEADS]) OR TRY_CONVERT(bigint,[StartingDEADS]) IS NULL)) OR ([OverallDEADSDelta] IS NOT NULL AND ([OverallDEADSDelta]<>FLOOR([OverallDEADSDelta]) OR TRY_CONVERT(bigint,[OverallDEADSDelta]) IS NULL)) OR ([DEADSDelta12Months] IS NOT NULL AND ([DEADSDelta12Months]<>FLOOR([DEADSDelta12Months]) OR TRY_CONVERT(bigint,[DEADSDelta12Months]) IS NULL)) OR ([DEADSDelta6Months] IS NOT NULL AND ([DEADSDelta6Months]<>FLOOR([DEADSDelta6Months]) OR TRY_CONVERT(bigint,[DEADSDelta6Months]) IS NULL)) OR ([DEADSDelta3Months] IS NOT NULL AND ([DEADSDelta3Months]<>FLOOR([DEADSDelta3Months]) OR TRY_CONVERT(bigint,[DEADSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.DEADSSUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K12D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K12D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4&T5_KILLSDelta12Months] IS NOT NULL AND ([T4&T5_KILLSDelta12Months]<>FLOOR([T4&T5_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta12Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K12D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K3D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K3D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4&T5_KILLSDelta3Months] IS NOT NULL AND ([T4&T5_KILLSDelta3Months]<>FLOOR([T4&T5_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K3D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K412D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K412D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4_KILLSDelta12Months] IS NOT NULL AND ([T4_KILLSDelta12Months]<>FLOOR([T4_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta12Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K412D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K43D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K43D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4_KILLSDelta3Months] IS NOT NULL AND ([T4_KILLSDelta3Months]<>FLOOR([T4_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K43D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K46D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K46D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4_KILLSDelta6Months] IS NOT NULL AND ([T4_KILLSDelta6Months]<>FLOOR([T4_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta6Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K46D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K512D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K512D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T5_KILLSDelta12Months] IS NOT NULL AND ([T5_KILLSDelta12Months]<>FLOOR([T5_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta12Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K512D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K53D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K53D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T5_KILLSDelta3Months] IS NOT NULL AND ([T5_KILLSDelta3Months]<>FLOOR([T5_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K53D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K56D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K56D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T5_KILLSDelta6Months] IS NOT NULL AND ([T5_KILLSDelta6Months]<>FLOOR([T5_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta6Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K56D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[K6D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[K6D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([T4&T5_KILLSDelta6Months] IS NOT NULL AND ([T4&T5_KILLSDelta6Months]<>FLOOR([T4&T5_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta6Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.K6D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILL4SUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILL4SUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T4_KILLS] IS NOT NULL AND ([T4_KILLS]<>FLOOR([T4_KILLS]) OR TRY_CONVERT(bigint,[T4_KILLS]) IS NULL)) OR ([StartingT4_KILLS] IS NOT NULL AND ([StartingT4_KILLS]<>FLOOR([StartingT4_KILLS]) OR TRY_CONVERT(bigint,[StartingT4_KILLS]) IS NULL)) OR ([OverallT4_KILLSDelta] IS NOT NULL AND ([OverallT4_KILLSDelta]<>FLOOR([OverallT4_KILLSDelta]) OR TRY_CONVERT(bigint,[OverallT4_KILLSDelta]) IS NULL)) OR ([T4_KILLSDelta12Months] IS NOT NULL AND ([T4_KILLSDelta12Months]<>FLOOR([T4_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta12Months]) IS NULL)) OR ([T4_KILLSDelta6Months] IS NOT NULL AND ([T4_KILLSDelta6Months]<>FLOOR([T4_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta6Months]) IS NULL)) OR ([T4_KILLSDelta3Months] IS NOT NULL AND ([T4_KILLSDelta3Months]<>FLOOR([T4_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILL4SUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILL5SUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILL5SUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T5_KILLS] IS NOT NULL AND ([T5_KILLS]<>FLOOR([T5_KILLS]) OR TRY_CONVERT(bigint,[T5_KILLS]) IS NULL)) OR ([StartingT5_KILLS] IS NOT NULL AND ([StartingT5_KILLS]<>FLOOR([StartingT5_KILLS]) OR TRY_CONVERT(bigint,[StartingT5_KILLS]) IS NULL)) OR ([OverallT5_KILLSDelta] IS NOT NULL AND ([OverallT5_KILLSDelta]<>FLOOR([OverallT5_KILLSDelta]) OR TRY_CONVERT(bigint,[OverallT5_KILLSDelta]) IS NULL)) OR ([T5_KILLSDelta12Months] IS NOT NULL AND ([T5_KILLSDelta12Months]<>FLOOR([T5_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta12Months]) IS NULL)) OR ([T5_KILLSDelta6Months] IS NOT NULL AND ([T5_KILLSDelta6Months]<>FLOOR([T5_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta6Months]) IS NULL)) OR ([T5_KILLSDelta3Months] IS NOT NULL AND ([T5_KILLSDelta3Months]<>FLOOR([T5_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T5_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILL5SUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLPOINTSSUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLPOINTSSUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLPOINTSSUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLPOINTS_D12D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLPOINTS_D12D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLPOINTS_D12D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLPOINTS_D3D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLPOINTS_D3D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLPOINTS_D3D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLPOINTS_D6D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLPOINTS_D6D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLPOINTS_D6D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLPOINTS_LATEST] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLPOINTS_LATEST] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLPOINTS_LATEST.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[KILLSUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[KILLSUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T4&T5_KILLS] IS NOT NULL AND ([T4&T5_KILLS]<>FLOOR([T4&T5_KILLS]) OR TRY_CONVERT(bigint,[T4&T5_KILLS]) IS NULL)) OR ([StartingT4&T5_KILLS] IS NOT NULL AND ([StartingT4&T5_KILLS]<>FLOOR([StartingT4&T5_KILLS]) OR TRY_CONVERT(bigint,[StartingT4&T5_KILLS]) IS NULL)) OR ([OverallT4&T5_KILLSDelta] IS NOT NULL AND ([OverallT4&T5_KILLSDelta]<>FLOOR([OverallT4&T5_KILLSDelta]) OR TRY_CONVERT(bigint,[OverallT4&T5_KILLSDelta]) IS NULL)) OR ([T4&T5_KILLSDelta12Months] IS NOT NULL AND ([T4&T5_KILLSDelta12Months]<>FLOOR([T4&T5_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta12Months]) IS NULL)) OR ([T4&T5_KILLSDelta6Months] IS NOT NULL AND ([T4&T5_KILLSDelta6Months]<>FLOOR([T4&T5_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta6Months]) IS NULL)) OR ([T4&T5_KILLSDelta3Months] IS NOT NULL AND ([T4&T5_KILLSDelta3Months]<>FLOOR([T4&T5_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.KILLSUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[LATEST] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[LATEST] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([PowerRank] IS NOT NULL AND ([PowerRank]<>FLOOR([PowerRank]) OR TRY_CONVERT(int,[PowerRank]) IS NULL)) OR ([DEADS] IS NOT NULL AND ([DEADS]<>FLOOR([DEADS]) OR TRY_CONVERT(bigint,[DEADS]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.LATEST.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[LATEST_POWER] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[LATEST_POWER] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([PowerRank] IS NOT NULL AND ([PowerRank]<>FLOOR([PowerRank]) OR TRY_CONVERT(int,[PowerRank]) IS NULL)) OR ([POWER] IS NOT NULL AND ([POWER]<>FLOOR([POWER]) OR TRY_CONVERT(bigint,[POWER]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.LATEST_POWER.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[LATEST_T4&T5_KILLS] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[LATEST_T4&T5_KILLS] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T4&T5_KILLS] IS NOT NULL AND ([T4&T5_KILLS]<>FLOOR([T4&T5_KILLS]) OR TRY_CONVERT(bigint,[T4&T5_KILLS]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.LATEST_T4&T5_KILLS.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[LATEST_T4_KILLS] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[LATEST_T4_KILLS] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T4_KILLS] IS NOT NULL AND ([T4_KILLS]<>FLOOR([T4_KILLS]) OR TRY_CONVERT(bigint,[T4_KILLS]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.LATEST_T4_KILLS.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[LATEST_T5_KILLS] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[LATEST_T5_KILLS] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERRank] IS NOT NULL AND ([POWERRank]<>FLOOR([POWERRank]) OR TRY_CONVERT(int,[POWERRank]) IS NULL)) OR ([T5_KILLS] IS NOT NULL AND ([T5_KILLS]<>FLOOR([T5_KILLS]) OR TRY_CONVERT(bigint,[T5_KILLS]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.LATEST_T5_KILLS.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[P12D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[P12D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERDelta12Months] IS NOT NULL AND ([POWERDelta12Months]<>FLOOR([POWERDelta12Months]) OR TRY_CONVERT(bigint,[POWERDelta12Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.P12D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[P3D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[P3D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERDelta3Months] IS NOT NULL AND ([POWERDelta3Months]<>FLOOR([POWERDelta3Months]) OR TRY_CONVERT(bigint,[POWERDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.P3D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[P6D] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[P6D] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([POWERDelta6Months] IS NOT NULL AND ([POWERDelta6Months]<>FLOOR([POWERDelta6Months]) OR TRY_CONVERT(bigint,[POWERDelta6Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.P6D.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[POWERSUMMARY] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[POWERSUMMARY] WHERE ([GovernorID] IS NOT NULL AND ([GovernorID]<>FLOOR([GovernorID]) OR TRY_CONVERT(bigint,[GovernorID]) IS NULL)) OR ([PowerRank] IS NOT NULL AND ([PowerRank]<>FLOOR([PowerRank]) OR TRY_CONVERT(int,[PowerRank]) IS NULL)) OR ([Power] IS NOT NULL AND ([Power]<>FLOOR([Power]) OR TRY_CONVERT(bigint,[Power]) IS NULL)) OR ([StartingPower] IS NOT NULL AND ([StartingPower]<>FLOOR([StartingPower]) OR TRY_CONVERT(bigint,[StartingPower]) IS NULL)) OR ([OverallPowerDelta] IS NOT NULL AND ([OverallPowerDelta]<>FLOOR([OverallPowerDelta]) OR TRY_CONVERT(bigint,[OverallPowerDelta]) IS NULL)) OR ([PowerDelta12Months] IS NOT NULL AND ([PowerDelta12Months]<>FLOOR([PowerDelta12Months]) OR TRY_CONVERT(bigint,[PowerDelta12Months]) IS NULL)) OR ([PowerDelta6Months] IS NOT NULL AND ([PowerDelta6Months]<>FLOOR([PowerDelta6Months]) OR TRY_CONVERT(bigint,[PowerDelta6Months]) IS NULL)) OR ([PowerDelta3Months] IS NOT NULL AND ([PowerDelta3Months]<>FLOOR([PowerDelta3Months]) OR TRY_CONVERT(bigint,[PowerDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.POWERSUMMARY.',1;
SELECT @locked_rows=COUNT_BIG(*) FROM [dbo].[SUMMARY_CHANGE_EXPORT] WITH(TABLOCKX,HOLDLOCK);
IF EXISTS(SELECT 1 FROM [dbo].[SUMMARY_CHANGE_EXPORT] WHERE ([GOVERNORID] IS NOT NULL AND ([GOVERNORID]<>FLOOR([GOVERNORID]) OR TRY_CONVERT(bigint,[GOVERNORID]) IS NULL)) OR ([T4&T5_KILLS] IS NOT NULL AND ([T4&T5_KILLS]<>FLOOR([T4&T5_KILLS]) OR TRY_CONVERT(bigint,[T4&T5_KILLS]) IS NULL)) OR ([StartingT4&T5_KILLS] IS NOT NULL AND ([StartingT4&T5_KILLS]<>FLOOR([StartingT4&T5_KILLS]) OR TRY_CONVERT(bigint,[StartingT4&T5_KILLS]) IS NULL)) OR ([OverallT4&T5_KILLSDelta] IS NOT NULL AND ([OverallT4&T5_KILLSDelta]<>FLOOR([OverallT4&T5_KILLSDelta]) OR TRY_CONVERT(bigint,[OverallT4&T5_KILLSDelta]) IS NULL)) OR ([T4&T5_KILLSDelta12Months] IS NOT NULL AND ([T4&T5_KILLSDelta12Months]<>FLOOR([T4&T5_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta12Months]) IS NULL)) OR ([T4&T5_KILLSDelta6Months] IS NOT NULL AND ([T4&T5_KILLSDelta6Months]<>FLOOR([T4&T5_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta6Months]) IS NULL)) OR ([T4&T5_KILLSDelta3Months] IS NOT NULL AND ([T4&T5_KILLSDelta3Months]<>FLOOR([T4&T5_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4&T5_KILLSDelta3Months]) IS NULL)) OR ([T4_KILLS] IS NOT NULL AND ([T4_KILLS]<>FLOOR([T4_KILLS]) OR TRY_CONVERT(bigint,[T4_KILLS]) IS NULL)) OR ([StartingT4_KILLS] IS NOT NULL AND ([StartingT4_KILLS]<>FLOOR([StartingT4_KILLS]) OR TRY_CONVERT(bigint,[StartingT4_KILLS]) IS NULL)) OR ([OverallT4_KILLSDelta] IS NOT NULL AND ([OverallT4_KILLSDelta]<>FLOOR([OverallT4_KILLSDelta]) OR TRY_CONVERT(bigint,[OverallT4_KILLSDelta]) IS NULL)) OR ([T4_KILLSDelta12Months] IS NOT NULL AND ([T4_KILLSDelta12Months]<>FLOOR([T4_KILLSDelta12Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta12Months]) IS NULL)) OR ([T4_KILLSDelta6Months] IS NOT NULL AND ([T4_KILLSDelta6Months]<>FLOOR([T4_KILLSDelta6Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta6Months]) IS NULL)) OR ([T4_KILLSDelta3Months] IS NOT NULL AND ([T4_KILLSDelta3Months]<>FLOOR([T4_KILLSDelta3Months]) OR TRY_CONVERT(bigint,[T4_KILLSDelta3Months]) IS NULL)) OR ([T5_Kills] IS NOT NULL AND ([T5_Kills]<>FLOOR([T5_Kills]) OR TRY_CONVERT(bigint,[T5_Kills]) IS NULL)) OR ([StartingT5_Kills] IS NOT NULL AND ([StartingT5_Kills]<>FLOOR([StartingT5_Kills]) OR TRY_CONVERT(bigint,[StartingT5_Kills]) IS NULL)) OR ([OverallT5_KillsDelta] IS NOT NULL AND ([OverallT5_KillsDelta]<>FLOOR([OverallT5_KillsDelta]) OR TRY_CONVERT(bigint,[OverallT5_KillsDelta]) IS NULL)) OR ([T5_KillsDelta12Months] IS NOT NULL AND ([T5_KillsDelta12Months]<>FLOOR([T5_KillsDelta12Months]) OR TRY_CONVERT(bigint,[T5_KillsDelta12Months]) IS NULL)) OR ([T5_KillsDelta6Months] IS NOT NULL AND ([T5_KillsDelta6Months]<>FLOOR([T5_KillsDelta6Months]) OR TRY_CONVERT(bigint,[T5_KillsDelta6Months]) IS NULL)) OR ([T5_KillsDelta3Months] IS NOT NULL AND ([T5_KillsDelta3Months]<>FLOOR([T5_KillsDelta3Months]) OR TRY_CONVERT(bigint,[T5_KillsDelta3Months]) IS NULL)) OR ([POWER] IS NOT NULL AND ([POWER]<>FLOOR([POWER]) OR TRY_CONVERT(bigint,[POWER]) IS NULL)) OR ([StartingPower] IS NOT NULL AND ([StartingPower]<>FLOOR([StartingPower]) OR TRY_CONVERT(bigint,[StartingPower]) IS NULL)) OR ([OverallPowerDelta] IS NOT NULL AND ([OverallPowerDelta]<>FLOOR([OverallPowerDelta]) OR TRY_CONVERT(bigint,[OverallPowerDelta]) IS NULL)) OR ([PowerDelta12Months] IS NOT NULL AND ([PowerDelta12Months]<>FLOOR([PowerDelta12Months]) OR TRY_CONVERT(bigint,[PowerDelta12Months]) IS NULL)) OR ([PowerDelta6Months] IS NOT NULL AND ([PowerDelta6Months]<>FLOOR([PowerDelta6Months]) OR TRY_CONVERT(bigint,[PowerDelta6Months]) IS NULL)) OR ([PowerDelta3Months] IS NOT NULL AND ([PowerDelta3Months]<>FLOOR([PowerDelta3Months]) OR TRY_CONVERT(bigint,[PowerDelta3Months]) IS NULL)) OR ([DEADS] IS NOT NULL AND ([DEADS]<>FLOOR([DEADS]) OR TRY_CONVERT(bigint,[DEADS]) IS NULL)) OR ([StartingDEADS] IS NOT NULL AND ([StartingDEADS]<>FLOOR([StartingDEADS]) OR TRY_CONVERT(bigint,[StartingDEADS]) IS NULL)) OR ([OverallDEADSDelta] IS NOT NULL AND ([OverallDEADSDelta]<>FLOOR([OverallDEADSDelta]) OR TRY_CONVERT(bigint,[OverallDEADSDelta]) IS NULL)) OR ([DEADSDelta12Months] IS NOT NULL AND ([DEADSDelta12Months]<>FLOOR([DEADSDelta12Months]) OR TRY_CONVERT(bigint,[DEADSDelta12Months]) IS NULL)) OR ([DEADSDelta6Months] IS NOT NULL AND ([DEADSDelta6Months]<>FLOOR([DEADSDelta6Months]) OR TRY_CONVERT(bigint,[DEADSDelta6Months]) IS NULL)) OR ([DEADSDelta3Months] IS NOT NULL AND ([DEADSDelta3Months]<>FLOOR([DEADSDelta3Months]) OR TRY_CONVERT(bigint,[DEADSDelta3Months]) IS NULL)) OR ([HealedTroops] IS NOT NULL AND ([HealedTroops]<>FLOOR([HealedTroops]) OR TRY_CONVERT(bigint,[HealedTroops]) IS NULL)) OR ([StartingHealed] IS NOT NULL AND ([StartingHealed]<>FLOOR([StartingHealed]) OR TRY_CONVERT(bigint,[StartingHealed]) IS NULL)) OR ([OverallHealedDelta] IS NOT NULL AND ([OverallHealedDelta]<>FLOOR([OverallHealedDelta]) OR TRY_CONVERT(bigint,[OverallHealedDelta]) IS NULL)) OR ([HealedDelta12Months] IS NOT NULL AND ([HealedDelta12Months]<>FLOOR([HealedDelta12Months]) OR TRY_CONVERT(bigint,[HealedDelta12Months]) IS NULL)) OR ([HealedDelta6Months] IS NOT NULL AND ([HealedDelta6Months]<>FLOOR([HealedDelta6Months]) OR TRY_CONVERT(bigint,[HealedDelta6Months]) IS NULL)) OR ([HealedDelta3Months] IS NOT NULL AND ([HealedDelta3Months]<>FLOOR([HealedDelta3Months]) OR TRY_CONVERT(bigint,[HealedDelta3Months]) IS NULL)) OR ([RangedPoints] IS NOT NULL AND ([RangedPoints]<>FLOOR([RangedPoints]) OR TRY_CONVERT(bigint,[RangedPoints]) IS NULL)) OR ([StartingRanged] IS NOT NULL AND ([StartingRanged]<>FLOOR([StartingRanged]) OR TRY_CONVERT(bigint,[StartingRanged]) IS NULL)) OR ([OverallRangedDelta] IS NOT NULL AND ([OverallRangedDelta]<>FLOOR([OverallRangedDelta]) OR TRY_CONVERT(bigint,[OverallRangedDelta]) IS NULL)) OR ([RangedDelta12Months] IS NOT NULL AND ([RangedDelta12Months]<>FLOOR([RangedDelta12Months]) OR TRY_CONVERT(bigint,[RangedDelta12Months]) IS NULL)) OR ([RangedDelta6Months] IS NOT NULL AND ([RangedDelta6Months]<>FLOOR([RangedDelta6Months]) OR TRY_CONVERT(bigint,[RangedDelta6Months]) IS NULL)) OR ([RangedDelta3Months] IS NOT NULL AND ([RangedDelta3Months]<>FLOOR([RangedDelta3Months]) OR TRY_CONVERT(bigint,[RangedDelta3Months]) IS NULL)) OR ([KillPoints] IS NOT NULL AND ([KillPoints]<>FLOOR([KillPoints]) OR TRY_CONVERT(bigint,[KillPoints]) IS NULL)) OR ([StartingKillPoints] IS NOT NULL AND ([StartingKillPoints]<>FLOOR([StartingKillPoints]) OR TRY_CONVERT(bigint,[StartingKillPoints]) IS NULL)) OR ([OverallKillPointsDelta] IS NOT NULL AND ([OverallKillPointsDelta]<>FLOOR([OverallKillPointsDelta]) OR TRY_CONVERT(bigint,[OverallKillPointsDelta]) IS NULL)) OR ([KillPointsDelta12Months] IS NOT NULL AND ([KillPointsDelta12Months]<>FLOOR([KillPointsDelta12Months]) OR TRY_CONVERT(bigint,[KillPointsDelta12Months]) IS NULL)) OR ([KillPointsDelta6Months] IS NOT NULL AND ([KillPointsDelta6Months]<>FLOOR([KillPointsDelta6Months]) OR TRY_CONVERT(bigint,[KillPointsDelta6Months]) IS NULL)) OR ([KillPointsDelta3Months] IS NOT NULL AND ([KillPointsDelta3Months]<>FLOOR([KillPointsDelta3Months]) OR TRY_CONVERT(bigint,[KillPointsDelta3Months]) IS NULL))) THROW 52980,'Unsafe numeric conversion: dbo.SUMMARY_CHANGE_EXPORT.',1;
DROP INDEX [IX_D12D_GovernorID] ON [dbo].[D12D];
DROP INDEX [IX_D3D_GovernorID] ON [dbo].[D3D];
DROP INDEX [IX_D6D_GovernorID] ON [dbo].[D6D];
DROP INDEX [IX_DEADSSUMMARY_PowerRank] ON [dbo].[DEADSSUMMARY];
DROP INDEX [UX_DEADSSUMMARY_GovernorID] ON [dbo].[DEADSSUMMARY];
DROP INDEX [IX_K12D_GovernorID] ON [dbo].[K12D];
DROP INDEX [IX_K3D_GovernorID] ON [dbo].[K3D];
DROP INDEX [IX_K412D_GovernorID] ON [dbo].[K412D];
DROP INDEX [IX_K43D_GovernorID] ON [dbo].[K43D];
DROP INDEX [IX_K46D_GovernorID] ON [dbo].[K46D];
DROP INDEX [IX_K512D_GovernorID] ON [dbo].[K512D];
DROP INDEX [IX_K53D_GovernorID] ON [dbo].[K53D];
DROP INDEX [IX_K56D_GovernorID] ON [dbo].[K56D];
DROP INDEX [IX_K6D_GovernorID] ON [dbo].[K6D];
DROP INDEX [UX_KILL4SUMMARY_GovernorID] ON [dbo].[KILL4SUMMARY];
DROP INDEX [UX_KILL5SUMMARY_GovernorID] ON [dbo].[KILL5SUMMARY];
DROP INDEX [IX_KILLPOINTSSUMMARY_PowerRank] ON [dbo].[KILLPOINTSSUMMARY];
ALTER TABLE [dbo].[KILLPOINTSSUMMARY] DROP CONSTRAINT [PK__KILLPOIN__2AF0592A2B1A7A85];
DROP INDEX [UX_KILLPOINTSSUMMARY_GovernorID] ON [dbo].[KILLPOINTSSUMMARY];
ALTER TABLE [dbo].[KILLPOINTS_D12D] DROP CONSTRAINT [PK__KILLPOIN__2AF0592A4AC6660B];
ALTER TABLE [dbo].[KILLPOINTS_D3D] DROP CONSTRAINT [PK__KILLPOIN__2AF0592A18CC7AAE];
ALTER TABLE [dbo].[KILLPOINTS_D6D] DROP CONSTRAINT [PK__KILLPOIN__2AF0592ABA34B941];
ALTER TABLE [dbo].[KILLPOINTS_LATEST] DROP CONSTRAINT [PK__KILLPOIN__2AF0592AACEF5529];
DROP INDEX [UX_KILLPOINTS_LATEST_GovernorID] ON [dbo].[KILLPOINTS_LATEST];
DROP INDEX [UX_KILLSUMMARY_GovernorID] ON [dbo].[KILLSUMMARY];
DROP INDEX [IX_LATEST_GovernorID] ON [dbo].[LATEST];
DROP INDEX [UX_LATEST_GovernorID] ON [dbo].[LATEST];
DROP INDEX [IX_LATEST_POWER_GovernorID] ON [dbo].[LATEST_POWER];
DROP INDEX [UX_LATEST_POWER_GovernorID] ON [dbo].[LATEST_POWER];
DROP INDEX [IX_LATEST_T4T5_KILLS_GovernorID] ON [dbo].[LATEST_T4&T5_KILLS];
DROP INDEX [UX_LATEST_T4T5_KILLS_GovernorID] ON [dbo].[LATEST_T4&T5_KILLS];
DROP INDEX [IX_LATEST_T4_KILLS_GovernorID] ON [dbo].[LATEST_T4_KILLS];
DROP INDEX [UX_LATEST_T4_KILLS_GovernorID] ON [dbo].[LATEST_T4_KILLS];
DROP INDEX [IX_LATEST_T5_KILLS_GovernorID] ON [dbo].[LATEST_T5_KILLS];
DROP INDEX [UX_LATEST_T5_KILLS_GovernorID] ON [dbo].[LATEST_T5_KILLS];
DROP INDEX [IX_P12D_GovernorID] ON [dbo].[P12D];
DROP INDEX [IX_P3D_GovernorID] ON [dbo].[P3D];
DROP INDEX [IX_P6D_GovernorID] ON [dbo].[P6D];
DROP INDEX [IX_POWERSUMMARY_PowerRank] ON [dbo].[POWERSUMMARY];
DROP INDEX [UX_POWERSUMMARY_GovernorID] ON [dbo].[POWERSUMMARY];
ALTER TABLE [dbo].[D12D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[D12D] ALTER COLUMN [DEADSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[D3D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[D3D] ALTER COLUMN [DEADSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[D6D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[D6D] ALTER COLUMN [DEADSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [PowerRank] int NOT NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [DEADS] bigint NOT NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [StartingDEADS] bigint NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [OverallDEADSDelta] bigint NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [DEADSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [DEADSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[DEADSSUMMARY] ALTER COLUMN [DEADSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[K12D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K12D] ALTER COLUMN [T4&T5_KILLSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[K3D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K3D] ALTER COLUMN [T4&T5_KILLSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[K412D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K412D] ALTER COLUMN [T4_KILLSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[K43D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K43D] ALTER COLUMN [T4_KILLSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[K46D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K46D] ALTER COLUMN [T4_KILLSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[K512D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K512D] ALTER COLUMN [T5_KILLSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[K53D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K53D] ALTER COLUMN [T5_KILLSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[K56D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K56D] ALTER COLUMN [T5_KILLSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[K6D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[K6D] ALTER COLUMN [T4&T5_KILLSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [T4_KILLS] bigint NOT NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [StartingT4_KILLS] bigint NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [OverallT4_KILLSDelta] bigint NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [T4_KILLSDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [T4_KILLSDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILL4SUMMARY] ALTER COLUMN [T4_KILLSDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [T5_KILLS] bigint NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [StartingT5_KILLS] bigint NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [OverallT5_KILLSDelta] bigint NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [T5_KILLSDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [T5_KILLSDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILL5SUMMARY] ALTER COLUMN [T5_KILLSDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILLPOINTSSUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLPOINTS_D12D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLPOINTS_D3D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLPOINTS_D6D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLPOINTS_LATEST] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [T4&T5_KILLS] bigint NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [StartingT4&T5_KILLS] bigint NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [OverallT4&T5_KILLSDelta] bigint NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [T4&T5_KILLSDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [T4&T5_KILLSDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[KILLSUMMARY] ALTER COLUMN [T4&T5_KILLSDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST] ALTER COLUMN [PowerRank] int NOT NULL;
ALTER TABLE [dbo].[LATEST] ALTER COLUMN [DEADS] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_POWER] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_POWER] ALTER COLUMN [PowerRank] int NOT NULL;
ALTER TABLE [dbo].[LATEST_POWER] ALTER COLUMN [POWER] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_T4&T5_KILLS] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_T4&T5_KILLS] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[LATEST_T4&T5_KILLS] ALTER COLUMN [T4&T5_KILLS] bigint NULL;
ALTER TABLE [dbo].[LATEST_T4_KILLS] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_T4_KILLS] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[LATEST_T4_KILLS] ALTER COLUMN [T4_KILLS] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_T5_KILLS] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[LATEST_T5_KILLS] ALTER COLUMN [POWERRank] int NOT NULL;
ALTER TABLE [dbo].[LATEST_T5_KILLS] ALTER COLUMN [T5_KILLS] bigint NOT NULL;
ALTER TABLE [dbo].[P12D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[P12D] ALTER COLUMN [POWERDelta12Months] bigint NULL;
ALTER TABLE [dbo].[P3D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[P3D] ALTER COLUMN [POWERDelta3Months] bigint NULL;
ALTER TABLE [dbo].[P6D] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[P6D] ALTER COLUMN [POWERDelta6Months] bigint NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [GovernorID] bigint NOT NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [PowerRank] int NOT NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [Power] bigint NOT NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [StartingPower] bigint NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [OverallPowerDelta] bigint NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [PowerDelta12Months] bigint NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [PowerDelta6Months] bigint NULL;
ALTER TABLE [dbo].[POWERSUMMARY] ALTER COLUMN [PowerDelta3Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [GOVERNORID] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4&T5_KILLS] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingT4&T5_KILLS] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallT4&T5_KILLSDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4&T5_KILLSDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4&T5_KILLSDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4&T5_KILLSDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4_KILLS] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingT4_KILLS] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallT4_KILLSDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4_KILLSDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4_KILLSDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T4_KILLSDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T5_Kills] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingT5_Kills] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallT5_KillsDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T5_KillsDelta12Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T5_KillsDelta6Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [T5_KillsDelta3Months] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [POWER] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingPower] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallPowerDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [PowerDelta12Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [PowerDelta6Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [PowerDelta3Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [DEADS] bigint NOT NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingDEADS] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallDEADSDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [DEADSDelta12Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [DEADSDelta6Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [DEADSDelta3Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [HealedTroops] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingHealed] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallHealedDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [HealedDelta12Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [HealedDelta6Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [HealedDelta3Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [RangedPoints] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingRanged] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallRangedDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [RangedDelta12Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [RangedDelta6Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [RangedDelta3Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [KillPoints] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [StartingKillPoints] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [OverallKillPointsDelta] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [KillPointsDelta12Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [KillPointsDelta6Months] bigint NULL;
ALTER TABLE [dbo].[SUMMARY_CHANGE_EXPORT] ALTER COLUMN [KillPointsDelta3Months] bigint NULL;
CREATE NONCLUSTERED INDEX [IX_D12D_GovernorID] ON [dbo].[D12D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_D3D_GovernorID] ON [dbo].[D3D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_D6D_GovernorID] ON [dbo].[D6D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_DEADSSUMMARY_PowerRank] ON [dbo].[DEADSSUMMARY] ([PowerRank] ASC) INCLUDE ([DEADS],[StartingDEADS],[OverallDEADSDelta],[DEADSDelta12Months],[DEADSDelta6Months],[DEADSDelta3Months]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_DEADSSUMMARY_GovernorID] ON [dbo].[DEADSSUMMARY] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K12D_GovernorID] ON [dbo].[K12D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K3D_GovernorID] ON [dbo].[K3D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K412D_GovernorID] ON [dbo].[K412D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K43D_GovernorID] ON [dbo].[K43D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K46D_GovernorID] ON [dbo].[K46D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K512D_GovernorID] ON [dbo].[K512D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K53D_GovernorID] ON [dbo].[K53D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K56D_GovernorID] ON [dbo].[K56D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_K6D_GovernorID] ON [dbo].[K6D] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_KILL4SUMMARY_GovernorID] ON [dbo].[KILL4SUMMARY] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_KILL5SUMMARY_GovernorID] ON [dbo].[KILL5SUMMARY] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_KILLPOINTSSUMMARY_PowerRank] ON [dbo].[KILLPOINTSSUMMARY] ([PowerRank] ASC) INCLUDE ([KillPoints],[StartingKillPoints],[OverallKillPointsDelta],[KillPointsDelta12Months],[KillPointsDelta6Months],[KillPointsDelta3Months]);
ALTER TABLE [dbo].[KILLPOINTSSUMMARY] ADD CONSTRAINT [PK__KILLPOIN__2AF0592A2B1A7A85] PRIMARY KEY CLUSTERED ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_KILLPOINTSSUMMARY_GovernorID] ON [dbo].[KILLPOINTSSUMMARY] ([GovernorID] ASC);
ALTER TABLE [dbo].[KILLPOINTS_D12D] ADD CONSTRAINT [PK__KILLPOIN__2AF0592A4AC6660B] PRIMARY KEY CLUSTERED ([GovernorID] ASC);
ALTER TABLE [dbo].[KILLPOINTS_D3D] ADD CONSTRAINT [PK__KILLPOIN__2AF0592A18CC7AAE] PRIMARY KEY CLUSTERED ([GovernorID] ASC);
ALTER TABLE [dbo].[KILLPOINTS_D6D] ADD CONSTRAINT [PK__KILLPOIN__2AF0592ABA34B941] PRIMARY KEY CLUSTERED ([GovernorID] ASC);
ALTER TABLE [dbo].[KILLPOINTS_LATEST] ADD CONSTRAINT [PK__KILLPOIN__2AF0592AACEF5529] PRIMARY KEY CLUSTERED ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_KILLPOINTS_LATEST_GovernorID] ON [dbo].[KILLPOINTS_LATEST] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_KILLSUMMARY_GovernorID] ON [dbo].[KILLSUMMARY] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_LATEST_GovernorID] ON [dbo].[LATEST] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_LATEST_GovernorID] ON [dbo].[LATEST] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_LATEST_POWER_GovernorID] ON [dbo].[LATEST_POWER] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_LATEST_POWER_GovernorID] ON [dbo].[LATEST_POWER] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_LATEST_T4T5_KILLS_GovernorID] ON [dbo].[LATEST_T4&T5_KILLS] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_LATEST_T4T5_KILLS_GovernorID] ON [dbo].[LATEST_T4&T5_KILLS] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_LATEST_T4_KILLS_GovernorID] ON [dbo].[LATEST_T4_KILLS] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_LATEST_T4_KILLS_GovernorID] ON [dbo].[LATEST_T4_KILLS] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_LATEST_T5_KILLS_GovernorID] ON [dbo].[LATEST_T5_KILLS] ([GovernorID] ASC);
CREATE UNIQUE NONCLUSTERED INDEX [UX_LATEST_T5_KILLS_GovernorID] ON [dbo].[LATEST_T5_KILLS] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_P12D_GovernorID] ON [dbo].[P12D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_P3D_GovernorID] ON [dbo].[P3D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_P6D_GovernorID] ON [dbo].[P6D] ([GovernorID] ASC);
CREATE NONCLUSTERED INDEX [IX_POWERSUMMARY_PowerRank] ON [dbo].[POWERSUMMARY] ([PowerRank] ASC) INCLUDE ([Power],[StartingPower],[OverallPowerDelta],[PowerDelta12Months],[PowerDelta6Months],[PowerDelta3Months]);
CREATE UNIQUE NONCLUSTERED INDEX [UX_POWERSUMMARY_GovernorID] ON [dbo].[POWERSUMMARY] ([GovernorID] ASC);
-- dbo.v_ReportGovernorNames
EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.v_ReportGovernorNames
AS
-- One current display name per identity. Alias history remains ALL_GOVS_NAMES.
-- Ignore empty observations; use the newest known name and a binary tie-break.
WITH Names AS (
    SELECT GovernorID, RTRIM(GovernorName) AS GovernorName,
           ROW_NUMBER() OVER (
               PARTITION BY GovernorID
               ORDER BY ScanOrder DESC,
                        RTRIM(GovernorName) COLLATE Latin1_General_100_BIN2 ASC
           ) AS NameOrder
    FROM dbo.KingdomScanData4
    WHERE GovernorID IS NOT NULL AND GovernorID <> 0
      AND GovernorID NOT IN (999999997,999999998,999999999)
      AND NULLIF(LTRIM(RTRIM(GovernorName)),N'''') IS NOT NULL
)
SELECT GovernorID, GovernorName FROM Names WHERE NameOrder=1;';
-- dbo.usp_ApplyReportGovernorNames
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_ApplyReportGovernorNames
    @Report sysname
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @Report IS NULL OR @Report NOT IN (N''DEADSSUMMARY'',N''POWERSUMMARY'',N''KILLSUMMARY'',N''KILL4SUMMARY'',N''KILL5SUMMARY'',N''KILLPOINTSSUMMARY'',N''HEALEDSUMMARY'',N''RANGEDSUMMARY'',N''SUMMARY_CHANGE_EXPORT'',N''POWER_BY_MONTH'',N''ALL_GOVS'',N''INACTIVE_GOVERNORS'',N''EXCEL_FOR_DASHBOARD'',N''DASH'',N''ALL_STATS_FOR_DASHBAORD'',N''STATS_FOR_UPLOAD'',N''RALLY_EXPORT'',N''CompletedReports'')
        THROW 52970, ''Unknown report name target.'', 1;
    -- Explicit targets only; names are applied AFTER numerical aggregation.
    -- Use the batch''s single list, or resolve it once for a standalone caller.
    CREATE TABLE #P02LocalReportNames (
        GovernorID bigint NOT NULL PRIMARY KEY,
        GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NOT NULL
    );
    IF OBJECT_ID(''tempdb..#P02ReportNames'') IS NOT NULL
        INSERT #P02LocalReportNames SELECT GovernorID,GovernorName FROM #P02ReportNames;
    ELSE
        INSERT #P02LocalReportNames SELECT GovernorID,GovernorName FROM dbo.v_ReportGovernorNames;
    IF @Report IN (N''DEADSSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[DEADSSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''POWERSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[POWERSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''KILLSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILLSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''KILL4SUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILL4SUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''KILL5SUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILL5SUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''KILLPOINTSSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[KILLPOINTSSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''HEALEDSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[HEALEDSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''RANGEDSUMMARY'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[RANGEDSUMMARY] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''SUMMARY_CHANGE_EXPORT'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[SUMMARY_CHANGE_EXPORT] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''POWER_BY_MONTH'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[POWER_BY_MONTH] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''ALL_GOVS'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[ALL_GOVS] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''INACTIVE_GOVERNORS'',N''CompletedReports'')
        UPDATE r SET [GovernorName]=n.GovernorName
        FROM dbo.[INACTIVE_GOVERNORS] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[GovernorID]
        WHERE r.[GovernorName] IS NULL
           OR RTRIM(r.[GovernorName]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''EXCEL_FOR_DASHBOARD'',N''CompletedReports'')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[EXCEL_FOR_DASHBOARD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''DASH'',N''CompletedReports'')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[DASH] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''ALL_STATS_FOR_DASHBAORD'',N''CompletedReports'')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[ALL_STATS_FOR_DASHBAORD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''STATS_FOR_UPLOAD'',N''CompletedReports'')
        UPDATE r SET [Governor_Name]=n.GovernorName
        FROM dbo.[STATS_FOR_UPLOAD] r
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=r.[Gov_ID]
        WHERE r.[Governor_Name] IS NULL
           OR RTRIM(r.[Governor_Name]) COLLATE Latin1_General_100_BIN2
              <> n.GovernorName COLLATE Latin1_General_100_BIN2;
    IF @Report IN (N''RALLY_EXPORT'',N''CompletedReports'')
    BEGIN
        -- Both existing rally producers use "name (GovernorID)". Preserve rows
        -- without that exact suffix rather than guessing identity from a name.
        UPDATE r SET GOVENOR=CONCAT(n.GovernorName,N'' ('',CONVERT(varchar(20),n.GovernorID),N'')'')
        FROM dbo.RALLY_EXPORT r
        CROSS APPLY (SELECT CHARINDEX(N''('',REVERSE(RTRIM(r.GOVENOR))) AS OpeningFromEnd) p
        CROSS APPLY (SELECT TRY_CONVERT(bigint,SUBSTRING(RTRIM(r.GOVENOR),
            LEN(RTRIM(r.GOVENOR))-p.OpeningFromEnd+2,
            CASE WHEN p.OpeningFromEnd>=3 THEN p.OpeningFromEnd-2 ELSE 0 END)) AS GovernorID) g
        INNER JOIN #P02LocalReportNames n ON n.GovernorID=g.GovernorID
        WHERE p.OpeningFromEnd>=3 AND RIGHT(RTRIM(r.GOVENOR),1)=N'')''
          AND RIGHT(RTRIM(r.GOVENOR),p.OpeningFromEnd+1)
              =CONCAT(N'' ('',CONVERT(varchar(20),n.GovernorID),N'')'')
          AND RTRIM(r.GOVENOR) COLLATE Latin1_General_100_BIN2
              <> CONCAT(n.GovernorName,N'' ('',CONVERT(varchar(20),n.GovernorID),N'')'') COLLATE Latin1_General_100_BIN2;
    END;
END;';
-- dbo.DEADSSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[DEADSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''Deads'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.Deads
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_DALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_DALL (GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, Deads, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D12(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_D12 (GovernorID, Deads, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, Deads, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D6(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_D6 (GovernorID, Deads, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, Deads, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_D3(
	[GovernorID] [bigint] NOT NULL,
	[DEADS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.Deads,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_D3 (GovernorID, Deads, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, Deads, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.Deads
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, Deads = src.Deads
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.Deads);

    DELETE d
    FROM dbo.D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D3D (GovernorID, DeadsDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D6D (GovernorID, DeadsDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.D12D (GovernorID, DeadsDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.Deads END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.Deads END))
    FROM dbo.LATEST L
    LEFT JOIN #P021_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.Deads END) AS StartingDeads,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.Deads END) AS EndingDeads
        FROM #P021_DALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.Deads,
            F.StartingDeads,
            CONVERT(decimal(38,0), F.EndingDeads) - CONVERT(decimal(38,0), F.StartingDeads) AS OverallDeadsDelta,
            ISNULL(D12D.DeadsDelta12Months, 0) AS DeadsDelta12Months,
            ISNULL(D6D.DeadsDelta6Months, 0) AS DeadsDelta6Months,
            ISNULL(D3D.DeadsDelta3Months, 0) AS DeadsDelta3Months
        FROM dbo.LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.DEADSSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            Deads = S.Deads,
            StartingDeads = S.StartingDeads,
            OverallDeadsDelta = S.OverallDeadsDelta,
            DeadsDelta12Months = S.DeadsDelta12Months,
            DeadsDelta6Months = S.DeadsDelta6Months,
            DeadsDelta3Months = S.DeadsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.Deads, S.StartingDeads, S.OverallDeadsDelta, S.DeadsDelta12Months, S.DeadsDelta6Months, S.DeadsDelta3Months);

    DELETE FROM dbo.DEADSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 50
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 100
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.DEADSSUMMARY (GovernorID, GovernorName, PowerRank, Deads, StartingDeads, OverallDeadsDelta, DeadsDelta12Months, DeadsDelta6Months, DeadsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), D.Deads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.StartingDeads)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.OverallDeadsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), D.DeadsDelta3Months)), 0)
    FROM dbo.DEADSSUMMARY AS D
    WHERE D.PowerRank <= 150
      AND D.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''DEADSSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.POWERSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[POWERSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''Power'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[POWER]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_PALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[POWER] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_PALL (GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [POWER], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_P12(
	[GovernorID] [bigint] NOT NULL,
	[POWER] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedP12 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_P12 (GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [POWER], ScanDate, RowAsc12, RowDesc12
    FROM RankedP12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_P6(
	[GovernorID] [bigint] NOT NULL,
	[POWER] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedP6 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_P6 (GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [POWER], ScanDate, RowAsc6, RowDesc6
    FROM RankedP6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_P3(
	[GovernorID] [bigint] NOT NULL,
	[POWER] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedP3 AS (
        SELECT g.GovernorID,
               g.[POWER],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_P3 (GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [POWER], ScanDate, RowAsc3, RowDesc3
    FROM RankedP3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_POWER AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[POWER]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, [POWER] = src.[POWER]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[POWER]);

    DELETE p3d
    FROM dbo.P3D p3d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p3d.GovernorID;

    INSERT INTO dbo.P3D (GovernorID, POWERDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN P3.RowDesc3 = 1 THEN P3.[POWER] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN P3.RowAsc3 = 1 THEN P3.[POWER] END))
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P3 P3 ON L.GovernorID = P3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p6d
    FROM dbo.P6D p6d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p6d.GovernorID;

    INSERT INTO dbo.P6D (GovernorID, POWERDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN P6.RowDesc6 = 1 THEN P6.[POWER] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN P6.RowAsc6 = 1 THEN P6.[POWER] END))
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P6 P6 ON L.GovernorID = P6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE p12d
    FROM dbo.P12D p12d
    INNER JOIN #AffectedGovs a ON a.GovernorID = p12d.GovernorID;

    INSERT INTO dbo.P12D (GovernorID, POWERDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN P12.RowDesc12 = 1 THEN P12.[POWER] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN P12.RowAsc12 = 1 THEN P12.[POWER] END))
    FROM dbo.LATEST_POWER L
    LEFT JOIN #P021_P12 P12 ON L.GovernorID = P12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT pa.GovernorID,
               MAX(CASE WHEN pa.RowAscALL = 1 THEN pa.[POWER] END) AS StartingPower,
               MAX(CASE WHEN pa.RowDescALL = 1 THEN pa.[POWER] END) AS EndingPower
        FROM #P021_PALL pa
        INNER JOIN #AffectedGovs a ON a.GovernorID = pa.GovernorID
        GROUP BY pa.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.[POWER],
            F.StartingPower,
            CONVERT(decimal(38,0), F.EndingPower) - CONVERT(decimal(38,0), F.StartingPower) AS OverallPowerDelta,
            ISNULL(P12D.PowerDelta12Months, 0) AS PowerDelta12Months,
            ISNULL(P6D.PowerDelta6Months, 0) AS PowerDelta6Months,
            ISNULL(P3D.PowerDelta3Months, 0) AS PowerDelta3Months
        FROM dbo.LATEST_POWER L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.P12D P12D ON L.GovernorID = P12D.GovernorID
        LEFT JOIN dbo.P6D P6D ON L.GovernorID = P6D.GovernorID
        LEFT JOIN dbo.P3D P3D ON L.GovernorID = P3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.POWERSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            [POWER] = S.[POWER],
            StartingPower = S.StartingPower,
            OverallPowerDelta = S.OverallPowerDelta,
            PowerDelta12Months = S.PowerDelta12Months,
            PowerDelta6Months = S.PowerDelta6Months,
            PowerDelta3Months = S.PowerDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.[POWER], S.StartingPower, S.OverallPowerDelta, S.PowerDelta12Months, S.PowerDelta6Months, S.PowerDelta3Months);

    DELETE FROM dbo.POWERSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), P.[POWER])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.StartingPower)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.OverallPowerDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta3Months)), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 50
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), P.[POWER])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.StartingPower)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.OverallPowerDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta3Months)), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 100
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.POWERSUMMARY (GovernorID, GovernorName, PowerRank, [POWER], StartingPower, OverallPowerDelta, PowerDelta12Months, PowerDelta6Months, PowerDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), P.[POWER])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.StartingPower)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.OverallPowerDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), P.PowerDelta3Months)), 0)
    FROM dbo.POWERSUMMARY AS P
    WHERE P.PowerRank <= 150
      AND P.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''POWERSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.KILLSSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[KILLSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''T4T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4&T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_KALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_KALL (GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4&T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K12(
	[GovernorID] [bigint] NOT NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K12 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K6(
	[GovernorID] [bigint] NOT NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K6 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K3(
	[GovernorID] [bigint] NOT NULL,
	[T4&T5_KILLS] [bigint] NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4&T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K3 (GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4&T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.[LATEST_T4&T5_KILLS] AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4&T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4&T5_KILLS] = src.[T4&T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4&T5_KILLS]);

    DELETE kd3
    FROM dbo.K3D kd3
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd3.GovernorID;

    INSERT INTO dbo.K3D (GovernorID, [T4&T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K3.RowDesc3 = 1 THEN K3.[T4&T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K3.RowAsc3 = 1 THEN K3.[T4&T5_KILLS] END))
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN #P021_K3 K3 ON L.GovernorID = K3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd6
    FROM dbo.K6D kd6
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd6.GovernorID;

    INSERT INTO dbo.K6D (GovernorID, [T4&T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K6.RowDesc6 = 1 THEN K6.[T4&T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K6.RowAsc6 = 1 THEN K6.[T4&T5_KILLS] END))
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN #P021_K6 K6 ON L.GovernorID = K6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE kd12
    FROM dbo.K12D kd12
    INNER JOIN #AffectedGovs a ON a.GovernorID = kd12.GovernorID;

    INSERT INTO dbo.K12D (GovernorID, [T4&T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K12.RowDesc12 = 1 THEN K12.[T4&T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K12.RowAsc12 = 1 THEN K12.[T4&T5_KILLS] END))
    FROM dbo.[LATEST_T4&T5_KILLS] L
    LEFT JOIN #P021_K12 K12 ON L.GovernorID = K12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ka.GovernorID,
               MAX(CASE WHEN ka.RowAscALL = 1 THEN ka.[T4&T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN ka.RowDescALL = 1 THEN ka.[T4&T5_KILLS] END) AS EndingKills
        FROM #P021_KALL ka
        INNER JOIN #AffectedGovs a ON a.GovernorID = ka.GovernorID
        GROUP BY ka.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T4&T5_KILLS],
            F.StartingKills,
            CONVERT(decimal(38,0), F.EndingKills) - CONVERT(decimal(38,0), F.StartingKills) AS OverallKillsDelta,
            ISNULL(K12D.[T4&T5_KILLSDelta12Months], 0) AS [T4&T5_KILLSDelta12Months],
            ISNULL(K6D.[T4&T5_KILLSDelta6Months], 0) AS [T4&T5_KILLSDelta6Months],
            ISNULL(K3D.[T4&T5_KILLSDelta3Months], 0) AS [T4&T5_KILLSDelta3Months]
        FROM dbo.[LATEST_T4&T5_KILLS] L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K12D K12D ON L.GovernorID = K12D.GovernorID
        LEFT JOIN dbo.K6D K6D ON L.GovernorID = K6D.GovernorID
        LEFT JOIN dbo.K3D K3D ON L.GovernorID = K3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILLSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T4&T5_KILLS] = S.[T4&T5_KILLS],
            [StartingT4&T5_KILLS] = S.StartingKills,
            [OverallT4&T5_KILLSDelta] = S.OverallKillsDelta,
            [T4&T5_KILLSDelta12Months] = S.[T4&T5_KILLSDelta12Months],
            [T4&T5_KILLSDelta6Months] = S.[T4&T5_KILLSDelta6Months],
            [T4&T5_KILLSDelta3Months] = S.[T4&T5_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4&T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4&T5_KILLSDelta12Months], S.[T4&T5_KILLSDelta6Months], S.[T4&T5_KILLSDelta3Months]);

    DELETE FROM dbo.KILLSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[StartingT4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[OverallT4&T5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta3Months])), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 50
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[StartingT4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[OverallT4&T5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta3Months])), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 100
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLSUMMARY (GovernorID, GovernorName, PowerRank, [T4&T5_KILLS], [StartingT4&T5_KILLS], [OverallT4&T5_KILLSDelta], [T4&T5_KILLSDelta12Months], [T4&T5_KILLSDelta6Months], [T4&T5_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[StartingT4&T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[OverallT4&T5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KS.[T4&T5_KILLSDelta3Months])), 0)
    FROM dbo.KILLSUMMARY AS KS
    WHERE KS.POWERRank <= 150
      AND KS.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''KILLSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.KT4SUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[KT4SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''T4Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T4_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K4ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T4_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_K4ALL (GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T4_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K412(
	[GovernorID] [bigint] NOT NULL,
	[T4_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K412 (GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K46(
	[GovernorID] [bigint] NOT NULL,
	[T4_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K46 (GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K43(
	[GovernorID] [bigint] NOT NULL,
	[T4_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T4_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K43 (GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T4_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T4_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T4_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T4_KILLS] = src.[T4_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T4_KILLS]);

    DELETE k43d
    FROM dbo.K43D k43d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k43d.GovernorID;

    INSERT INTO dbo.K43D (GovernorID, [T4_KILLSDelta3Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K43.RowDesc3 = 1 THEN K43.[T4_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K43.RowAsc3 = 1 THEN K43.[T4_KILLS] END))
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K43 K43 ON L.GovernorID = K43.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k46d
    FROM dbo.K46D k46d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k46d.GovernorID;

    INSERT INTO dbo.K46D (GovernorID, [T4_KILLSDelta6Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K46.RowDesc6 = 1 THEN K46.[T4_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K46.RowAsc6 = 1 THEN K46.[T4_KILLS] END))
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K46 K46 ON L.GovernorID = K46.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k412d
    FROM dbo.K412D k412d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k412d.GovernorID;

    INSERT INTO dbo.K412D (GovernorID, [T4_KILLSDelta12Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K412.RowDesc12 = 1 THEN K412.[T4_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K412.RowAsc12 = 1 THEN K412.[T4_KILLS] END))
    FROM dbo.LATEST_T4_KILLS L
    LEFT JOIN #P021_K412 K412 ON L.GovernorID = K412.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k4a.GovernorID,
               MAX(CASE WHEN k4a.RowAscALL = 1 THEN k4a.[T4_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k4a.RowDescALL = 1 THEN k4a.[T4_KILLS] END) AS EndingKills
        FROM #P021_K4ALL k4a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k4a.GovernorID
        GROUP BY k4a.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T4_KILLS],
            F.StartingKills,
            CONVERT(decimal(38,0), F.EndingKills) - CONVERT(decimal(38,0), F.StartingKills) AS OverallKillsDelta,
            ISNULL(K412D.[T4_KILLSDelta12Months], 0) AS [T4_KILLSDelta12Months],
            ISNULL(K46D.[T4_KILLSDelta6Months], 0) AS [T4_KILLSDelta6Months],
            ISNULL(K43D.[T4_KILLSDelta3Months], 0) AS [T4_KILLSDelta3Months]
        FROM dbo.LATEST_T4_KILLS L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K412D K412D ON L.GovernorID = K412D.GovernorID
        LEFT JOIN dbo.K46D K46D ON L.GovernorID = K46D.GovernorID
        LEFT JOIN dbo.K43D K43D ON L.GovernorID = K43D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILL4SUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T4_KILLS] = S.[T4_KILLS],
            [StartingT4_KILLS] = S.StartingKills,
            [OverallT4_KILLSDelta] = S.OverallKillsDelta,
            [T4_KILLSDelta12Months] = S.[T4_KILLSDelta12Months],
            [T4_KILLSDelta6Months] = S.[T4_KILLSDelta6Months],
            [T4_KILLSDelta3Months] = S.[T4_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T4_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T4_KILLSDelta12Months], S.[T4_KILLSDelta6Months], S.[T4_KILLSDelta3Months]);

    DELETE FROM dbo.KILL4SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[StartingT4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[OverallT4_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta3Months])), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 50
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[StartingT4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[OverallT4_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta3Months])), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 100
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL4SUMMARY (GovernorID, GovernorName, POWERRank, [T4_KILLS], [StartingT4_KILLS], [OverallT4_KILLSDelta], [T4_KILLSDelta12Months], [T4_KILLSDelta6Months], [T4_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[StartingT4_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[OverallT4_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K4.[T4_KILLSDelta3Months])), 0)
    FROM dbo.KILL4SUMMARY AS K4
    WHERE K4.POWERRank <= 150
      AND K4.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''KILL4SUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.KT5SUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[KT5SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''T5Kills'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.[T5_KILLS]
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K5ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[T5_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAscALL] [bigint] NULL,
	[RowDescALL] [bigint] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_K5ALL (GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, [T5_KILLS], ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K512(
	[GovernorID] [bigint] NOT NULL,
	[T5_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc12] [bigint] NULL,
	[RowDesc12] [bigint] NULL
    );

    ;WITH RankedK12 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_K512 (GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc12, RowDesc12
    FROM RankedK12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K56(
	[GovernorID] [bigint] NOT NULL,
	[T5_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc6] [bigint] NULL,
	[RowDesc6] [bigint] NULL
    );

    ;WITH RankedK6 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_K56 (GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc6, RowDesc6
    FROM RankedK6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_K53(
	[GovernorID] [bigint] NOT NULL,
	[T5_KILLS] [bigint] NOT NULL,
	[ScanDate] [datetime] NOT NULL,
	[RowAsc3] [bigint] NULL,
	[RowDesc3] [bigint] NULL
    );

    ;WITH RankedK3 AS (
        SELECT g.GovernorID,
               g.[T5_KILLS],
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_K53 (GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, [T5_KILLS], ScanDate, RowAsc3, RowDesc3
    FROM RankedK3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.LATEST_T5_KILLS AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.[T5_KILLS]
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, POWERRank = src.PowerRank, [T5_KILLS] = src.[T5_KILLS]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS])
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.[T5_KILLS]);

    DELETE k53d
    FROM dbo.K53D k53d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k53d.GovernorID;

    INSERT INTO dbo.K53D (GovernorID, [T5_KILLSDelta3Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K53.RowDesc3 = 1 THEN K53.[T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K53.RowAsc3 = 1 THEN K53.[T5_KILLS] END))
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K53 K53 ON L.GovernorID = K53.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k56d
    FROM dbo.K56D k56d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k56d.GovernorID;

    INSERT INTO dbo.K56D (GovernorID, [T5_KILLSDelta6Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K56.RowDesc6 = 1 THEN K56.[T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K56.RowAsc6 = 1 THEN K56.[T5_KILLS] END))
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K56 K56 ON L.GovernorID = K56.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE k512d
    FROM dbo.K512D k512d
    INNER JOIN #AffectedGovs a ON a.GovernorID = k512d.GovernorID;

    INSERT INTO dbo.K512D (GovernorID, [T5_KILLSDelta12Months])
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN K512.RowDesc12 = 1 THEN K512.[T5_KILLS] END)) - CONVERT(decimal(38,0), MAX(CASE WHEN K512.RowAsc12 = 1 THEN K512.[T5_KILLS] END))
    FROM dbo.LATEST_T5_KILLS L
    LEFT JOIN #P021_K512 K512 ON L.GovernorID = K512.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT k5a.GovernorID,
               MAX(CASE WHEN k5a.RowAscALL = 1 THEN k5a.[T5_KILLS] END) AS StartingKills,
               MAX(CASE WHEN k5a.RowDescALL = 1 THEN k5a.[T5_KILLS] END) AS EndingKills
        FROM #P021_K5ALL k5a
        INNER JOIN #AffectedGovs a ON a.GovernorID = k5a.GovernorID
        GROUP BY k5a.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.POWERRank,
            L.[T5_KILLS],
            F.StartingKills,
            CONVERT(decimal(38,0), F.EndingKills) - CONVERT(decimal(38,0), F.StartingKills) AS OverallKillsDelta,
            ISNULL(K512D.[T5_KILLSDelta12Months], 0) AS [T5_KILLSDelta12Months],
            ISNULL(K56D.[T5_KILLSDelta6Months], 0) AS [T5_KILLSDelta6Months],
            ISNULL(K53D.[T5_KILLSDelta3Months], 0) AS [T5_KILLSDelta3Months]
        FROM dbo.LATEST_T5_KILLS L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.K512D K512D ON L.GovernorID = K512D.GovernorID
        LEFT JOIN dbo.K56D K56D ON L.GovernorID = K56D.GovernorID
        LEFT JOIN dbo.K53D K53D ON L.GovernorID = K53D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILL5SUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            POWERRank = S.POWERRank,
            [T5_KILLS] = S.[T5_KILLS],
            [StartingT5_KILLS] = S.StartingKills,
            [OverallT5_KILLSDelta] = S.OverallKillsDelta,
            [T5_KILLSDelta12Months] = S.[T5_KILLSDelta12Months],
            [T5_KILLSDelta6Months] = S.[T5_KILLSDelta6Months],
            [T5_KILLSDelta3Months] = S.[T5_KILLSDelta3Months]
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
        VALUES (S.GovernorID, S.GovernorName, S.POWERRank, S.[T5_KILLS], S.StartingKills, S.OverallKillsDelta, S.[T5_KILLSDelta12Months], S.[T5_KILLSDelta6Months], S.[T5_KILLSDelta3Months]);

    DELETE FROM dbo.KILL5SUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[StartingT5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[OverallT5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta3Months])), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 50
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[StartingT5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[OverallT5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta3Months])), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 100
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILL5SUMMARY (GovernorID, GovernorName, POWERRank, [T5_KILLS], [StartingT5_KILLS], [OverallT5_KILLSDelta], [T5_KILLSDelta12Months], [T5_KILLSDelta6Months], [T5_KILLSDelta3Months])
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[StartingT5_KILLS])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[OverallT5_KILLSDelta])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta12Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta6Months])), 0),
           ROUND(AVG(CONVERT(decimal(38,6), K5.[T5_KILLSDelta3Months])), 0)
    FROM dbo.KILL5SUMMARY AS K5
    WHERE K5.POWERRank <= 150
      AND K5.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''KILL5SUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.KILLPOINTSSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[KILLPOINTSSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''KillPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.KillPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_KILLPOINTS_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_KILLPOINTS_ALL (GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, KillPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_KILLPOINTS_D12(
	[GovernorID] [bigint] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_KILLPOINTS_D12 (GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_KILLPOINTS_D6(
	[GovernorID] [bigint] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_KILLPOINTS_D6 (GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_KILLPOINTS_D3(
	[GovernorID] [bigint] NOT NULL,
	[KillPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.KillPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_KILLPOINTS_D3 (GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, KillPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.KILLPOINTS_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.KillPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, KillPoints = src.KillPoints
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.KillPoints);

    DELETE d
    FROM dbo.KILLPOINTS_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D3D (GovernorID, KillPointsDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.KillPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.KillPoints END))
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D6D (GovernorID, KillPointsDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.KillPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.KillPoints END))
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.KILLPOINTS_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.KILLPOINTS_D12D (GovernorID, KillPointsDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.KillPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.KillPoints END))
    FROM dbo.KILLPOINTS_LATEST L
    LEFT JOIN #P021_KILLPOINTS_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT kp.GovernorID,
               MAX(CASE WHEN kp.RowAscALL = 1 THEN kp.KillPoints END) AS StartingKillPoints,
               MAX(CASE WHEN kp.RowDescALL = 1 THEN kp.KillPoints END) AS EndingKillPoints
        FROM #P021_KILLPOINTS_ALL kp
        INNER JOIN #AffectedGovs a ON a.GovernorID = kp.GovernorID
        GROUP BY kp.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.KillPoints,
            F.StartingKillPoints,
            CONVERT(decimal(38,0), F.EndingKillPoints) - CONVERT(decimal(38,0), F.StartingKillPoints) AS OverallKillPointsDelta,
            ISNULL(D12D.KillPointsDelta12Months, 0) AS KillPointsDelta12Months,
            ISNULL(D6D.KillPointsDelta6Months, 0) AS KillPointsDelta6Months,
            ISNULL(D3D.KillPointsDelta3Months, 0) AS KillPointsDelta3Months
        FROM dbo.KILLPOINTS_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.KILLPOINTS_D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.KILLPOINTSSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            KillPoints = S.KillPoints,
            StartingKillPoints = S.StartingKillPoints,
            OverallKillPointsDelta = S.OverallKillPointsDelta,
            KillPointsDelta12Months = S.KillPointsDelta12Months,
            KillPointsDelta6Months = S.KillPointsDelta6Months,
            KillPointsDelta3Months = S.KillPointsDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.KillPoints, S.StartingKillPoints, S.OverallKillPointsDelta, S.KillPointsDelta12Months, S.KillPointsDelta6Months, S.KillPointsDelta3Months);

    DELETE FROM dbo.KILLPOINTSSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.StartingKillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.OverallKillPointsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta3Months)), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 50
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.StartingKillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.OverallKillPointsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta3Months)), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 100
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.KILLPOINTSSUMMARY (GovernorID, GovernorName, PowerRank, KillPoints, StartingKillPoints, OverallKillPointsDelta, KillPointsDelta12Months, KillPointsDelta6Months, KillPointsDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.StartingKillPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.OverallKillPointsDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), KP.KillPointsDelta3Months)), 0)
    FROM dbo.KILLPOINTSSUMMARY AS KP
    WHERE KP.PowerRank <= 150
      AND KP.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''KILLPOINTSSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.HEALEDSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    /* Optional independent mode */
    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_HEALED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_HEALED_D12(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_HEALED_D6(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_HEALED_D3(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.HealedTroops,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.HEALED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN
        UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
        VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

    DELETE d
    FROM dbo.HEALED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END))
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END))
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.HEALED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END))
    FROM dbo.HEALED_LATEST L
    LEFT JOIN #P021_HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT d.GovernorID,
               MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
               MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
        FROM #P021_HEALED_ALL d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
        GROUP BY d.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.HealedTroops,
            F.StartingHealed,
            CONVERT(decimal(38,0), F.EndingHealed) - CONVERT(decimal(38,0), F.StartingHealed) AS OverallHealedDelta,
            ISNULL(D12D.HealedTroopsDelta12Months, 0) AS HealedDelta12Months,
            ISNULL(D6D.HealedTroopsDelta6Months, 0) AS HealedDelta6Months,
            ISNULL(D3D.HealedTroopsDelta3Months, 0) AS HealedDelta3Months
        FROM dbo.HEALED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.HEALED_D12D D12D ON L.GovernorID = D12D.GovernorID
        LEFT JOIN dbo.HEALED_D6D D6D ON L.GovernorID = D6D.GovernorID
        LEFT JOIN dbo.HEALED_D3D D3D ON L.GovernorID = D3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.HEALEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            HealedTroops = S.HealedTroops,
            StartingHealed = S.StartingHealed,
            OverallHealedDelta = S.OverallHealedDelta,
            HealedDelta12Months = S.HealedDelta12Months,
            HealedDelta6Months = S.HealedDelta6Months,
            HealedDelta3Months = S.HealedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.HealedTroops, S.StartingHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

    DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 50
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 100
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
    FROM dbo.HEALEDSUMMARY AS H
    WHERE H.PowerRank <= 150
      AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''HEALEDSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.RANGEDSUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[RANGEDSUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Direct calls and parent calls share atomic output/state failure semantics.
    BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @MetricName NVARCHAR(100) = N''RangedPoints'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    DECLARE @UseSharedTemps BIT = CASE
        WHEN OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL
         AND OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL
        THEN 1 ELSE 0 END;

    IF @UseSharedTemps = 1
    BEGIN
        SELECT @MaxScan = MaxScan FROM #SummaryRunState;
    END
    ELSE
    BEGIN
        SELECT @LastProcessed = LastScanOrder
        FROM dbo.SUMMARY_PROC_STATE
        WHERE MetricName = @MetricName;

        IF @LastProcessed IS NULL SET @LastProcessed = 0;

        SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
        FROM dbo.KingdomScanData4;

        IF @MaxScan <= @LastProcessed
        BEGIN
            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
        COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);
    END

    DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
    DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
    DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
    DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_RANGED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
    );

    ;WITH RankedAll AS (
        SELECT g.GovernorID,
               g.GovernorName,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
        FROM #GovScan g
    )
    INSERT INTO #P021_RANGED_ALL (GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL)
    SELECT GovernorID, GovernorName, RangedPoints, ScanDate, RowAscALL, RowDescALL
    FROM RankedAll
    WHERE RowAscALL = 1 OR RowDescALL = 1;

    ;WITH LatestScanOrder AS (
        SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
        FROM #GovScan g
        GROUP BY g.GovernorID
    )
    MERGE dbo.RANGED_LATEST AS tgt
    USING (
        SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.RangedPoints
        FROM #GovScan g
        INNER JOIN LatestScanOrder l ON l.GovernorID = g.GovernorID AND l.LatestScanOrder = g.ScanOrder
    ) AS src
    ON tgt.GovernorID = src.GovernorID
    WHEN MATCHED THEN UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, RangedPoints = src.RangedPoints
    WHEN NOT MATCHED THEN INSERT (GovernorID, GovernorName, PowerRank, RangedPoints)
    VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.RangedPoints);

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_RANGED_D3(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
    );

    ;WITH RankedD3 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc3,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc3
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff3
    )
    INSERT INTO #P021_RANGED_D3 (GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc3, RowDesc3
    FROM RankedD3
    WHERE RowAsc3 = 1 OR RowDesc3 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_RANGED_D6(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
    );

    ;WITH RankedD6 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc6,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc6
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff6
    )
    INSERT INTO #P021_RANGED_D6 (GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc6, RowDesc6
    FROM RankedD6
    WHERE RowAsc6 = 1 OR RowDesc6 = 1;

    -- Retain only first/last rows; use exact count/ID types and preserve ranking.
    CREATE TABLE #P021_RANGED_D12(
	[GovernorID] [bigint] NOT NULL,
	[RangedPoints] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
    );

    ;WITH RankedD12 AS (
        SELECT g.GovernorID,
               g.RangedPoints,
               g.ScanDate,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAsc12,
               ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDesc12
        FROM #GovScan g
        WHERE g.ScanDate >= @Cutoff12
    )
    INSERT INTO #P021_RANGED_D12 (GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12)
    SELECT GovernorID, RangedPoints, ScanDate, RowAsc12, RowDesc12
    FROM RankedD12
    WHERE RowAsc12 = 1 OR RowDesc12 = 1;

    DELETE d
    FROM dbo.RANGED_D3D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D3D (GovernorID, RangedPointsDelta3Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.RangedPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.RangedPoints END))
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D3 D3 ON L.GovernorID = D3.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D6D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D6D (GovernorID, RangedPointsDelta6Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.RangedPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.RangedPoints END))
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D6 D6 ON L.GovernorID = D6.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    DELETE d
    FROM dbo.RANGED_D12D d
    INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

    INSERT INTO dbo.RANGED_D12D (GovernorID, RangedPointsDelta12Months)
    SELECT L.GovernorID,
           CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.RangedPoints END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.RangedPoints END))
    FROM dbo.RANGED_LATEST L
    LEFT JOIN #P021_RANGED_D12 D12 ON L.GovernorID = D12.GovernorID
    INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    GROUP BY L.GovernorID;

    ;WITH FirstLastAll AS (
        SELECT ra.GovernorID,
               MAX(CASE WHEN ra.RowAscALL = 1 THEN ra.RangedPoints END) AS StartingRanged,
               MAX(CASE WHEN ra.RowDescALL = 1 THEN ra.RangedPoints END) AS EndingRanged
        FROM #P021_RANGED_ALL ra
        INNER JOIN #AffectedGovs a ON a.GovernorID = ra.GovernorID
        GROUP BY ra.GovernorID
    ),
    Source AS (
        SELECT
            L.GovernorID,
            L.GovernorName,
            L.PowerRank,
            L.RangedPoints,
            F.StartingRanged,
            CONVERT(decimal(38,0), F.EndingRanged) - CONVERT(decimal(38,0), F.StartingRanged) AS OverallRangedDelta,
            ISNULL(R12D.RangedPointsDelta12Months, 0) AS RangedDelta12Months,
            ISNULL(R6D.RangedPointsDelta6Months, 0) AS RangedDelta6Months,
            ISNULL(R3D.RangedPointsDelta3Months, 0) AS RangedDelta3Months
        FROM dbo.RANGED_LATEST L
        INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
        LEFT JOIN dbo.RANGED_D12D R12D ON L.GovernorID = R12D.GovernorID
        LEFT JOIN dbo.RANGED_D6D R6D ON L.GovernorID = R6D.GovernorID
        LEFT JOIN dbo.RANGED_D3D R3D ON L.GovernorID = R3D.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
    )
    MERGE dbo.RANGEDSUMMARY AS T
    USING Source AS S
    ON T.GovernorID = S.GovernorID
    WHEN MATCHED THEN
        UPDATE SET
            GovernorName = S.GovernorName,
            PowerRank = S.PowerRank,
            RangedPoints = S.RangedPoints,
            StartingRanged = S.StartingRanged,
            OverallRangedDelta = S.OverallRangedDelta,
            RangedDelta12Months = S.RangedDelta12Months,
            RangedDelta6Months = S.RangedDelta6Months,
            RangedDelta3Months = S.RangedDelta3Months
    WHEN NOT MATCHED THEN
        INSERT (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
        VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.RangedPoints, S.StartingRanged, S.OverallRangedDelta, S.RangedDelta12Months, S.RangedDelta6Months, S.RangedDelta3Months);

    DELETE FROM dbo.RANGEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999997, ''Top50'', 50,
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.StartingRanged)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.OverallRangedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta3Months)), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 50
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999998, ''Top100'', 100,
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.StartingRanged)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.OverallRangedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta3Months)), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 100
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    INSERT INTO dbo.RANGEDSUMMARY (GovernorID, GovernorName, PowerRank, RangedPoints, StartingRanged, OverallRangedDelta, RangedDelta12Months, RangedDelta6Months, RangedDelta3Months)
    SELECT 999999999, ''Kingdom Average'', 150,
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedPoints)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.StartingRanged)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.OverallRangedDelta)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta12Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta6Months)), 0),
           ROUND(AVG(CONVERT(decimal(38,6), R.RangedDelta3Months)), 0)
    FROM dbo.RANGEDSUMMARY AS R
    WHERE R.PowerRank <= 150
      AND R.GovernorID NOT IN (999999997, 999999998, 999999999);

    MERGE dbo.SUMMARY_PROC_STATE AS T
    USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
    ON T.MetricName = S.MetricName
    WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
    WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
    VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''RANGEDSUMMARY'';
    COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END';
-- dbo.SUMMARY_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[SUMMARY_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''SummaryExport'';
    DECLARE @MinLastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    SELECT @MinLastProcessed = MIN(ISNULL(LastScanOrder, 0))
    FROM dbo.SUMMARY_PROC_STATE
    WHERE MetricName IN (
        N''Deads'',
        N''Power'',
        N''T4T5Kills'',
        N''T4Kills'',
        N''T5Kills'',
        N''KillPoints'',
        N''HealedTroops'',
        N''RangedPoints''
    );

    IF @MinLastProcessed IS NULL SET @MinLastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
    FROM dbo.KingdomScanData4;

    IF @MaxScan <= @MinLastProcessed
    BEGIN
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        IF OBJECT_ID(''tempdb..#SummaryRunState'') IS NOT NULL DROP TABLE #SummaryRunState;
        CREATE TABLE #SummaryRunState
        (
            MaxScan INT NOT NULL,
            MinLastProcessed INT NOT NULL
        );

        INSERT INTO #SummaryRunState (MaxScan, MinLastProcessed)
        VALUES (@MaxScan, @MinLastProcessed);

        IF OBJECT_ID(''tempdb..#AffectedGovs'') IS NOT NULL DROP TABLE #AffectedGovs;
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @MinLastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
            VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT TRANSACTION;
            RETURN;
        END

        IF OBJECT_ID(''tempdb..#GovScan'') IS NOT NULL DROP TABLE #GovScan;
        SELECT
            ks4.GovernorID,
            ks4.GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops,
            ks4.Deads,
            ks4.KillPoints,
            ks4.[T4&T5_KILLS],
            ks4.[T4_KILLS],
            ks4.[T5_KILLS],
            ks4.[POWER],
            ks4.RangedPoints
        INTO #GovScan
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        -- Execute dependent procedures (shared temp tables visible)
        EXEC dbo.DEADSSUMMARY_PROC;
        EXEC dbo.POWERSUMMARY_PROC;
        EXEC dbo.KILLSSUMMARY_PROC;
        EXEC dbo.KT4SUMMARY_PROC;
        EXEC dbo.KT5SUMMARY_PROC;
        EXEC dbo.KILLPOINTSSUMMARY_PROC;
        EXEC dbo.HEALEDSUMMARY_PROC;
        EXEC dbo.RANGEDSUMMARY_PROC;

        -- Clear export table
        TRUNCATE TABLE dbo.SUMMARY_CHANGE_EXPORT;

        -- Insert combined summary data
        INSERT INTO dbo.SUMMARY_CHANGE_EXPORT
        (
            GOVERNORID,
            GOVERNORNAME,
            [T4&T5_KILLS],
            [StartingT4&T5_KILLS],
            [OverallT4&T5_KILLSDelta],
            [T4&T5_KILLSDelta12Months],
            [T4&T5_KILLSDelta6Months],
            [T4&T5_KILLSDelta3Months],
            [T4_KILLS],
            [StartingT4_KILLS],
            [OverallT4_KILLSDelta],
            [T4_KILLSDelta12Months],
            [T4_KILLSDelta6Months],
            [T4_KILLSDelta3Months],
            [T5_KILLS],
            [StartingT5_KILLS],
            [OverallT5_KILLSDelta],
            [T5_KILLSDelta12Months],
            [T5_KILLSDelta6Months],
            [T5_KILLSDelta3Months],
            [POWER],
            StartingPower,
            OverallPowerDelta,
            PowerDelta12Months,
            PowerDelta6Months,
            PowerDelta3Months,
            DEADS,
            StartingDEADS,
            OverallDEADSDelta,
            DEADSDelta12Months,
            DEADSDelta6Months,
            DEADSDelta3Months,
            HealedTroops,
            StartingHealed,
            OverallHealedDelta,
            HealedDelta12Months,
            HealedDelta6Months,
            HealedDelta3Months,
            RangedPoints,
            StartingRanged,
            OverallRangedDelta,
            RangedDelta12Months,
            RangedDelta6Months,
            RangedDelta3Months,
            KillPoints,
            StartingKillPoints,
            OverallKillPointsDelta,
            KillPointsDelta12Months,
            KillPointsDelta6Months,
            KillPointsDelta3Months
        )
        SELECT 
            P.GOVERNORID,
            P.GOVERNORNAME,
            K.[T4&T5_KILLS],
            K.[StartingT4&T5_KILLS],
            K.[OverallT4&T5_KILLSDelta],
            K.[T4&T5_KILLSDelta12Months],
            K.[T4&T5_KILLSDelta6Months],
            K.[T4&T5_KILLSDelta3Months],
            K4.[T4_KILLS],
            K4.[StartingT4_KILLS],
            K4.[OverallT4_KILLSDelta],
            K4.[T4_KILLSDelta12Months],
            K4.[T4_KILLSDelta6Months],
            K4.[T4_KILLSDelta3Months],
            K5.[T5_KILLS],
            K5.[StartingT5_KILLS],
            K5.[OverallT5_KILLSDelta],
            K5.[T5_KILLSDelta12Months],
            K5.[T5_KILLSDelta6Months],
            K5.[T5_KILLSDelta3Months],
            P.[POWER],
            P.StartingPower,
            P.OverallPowerDelta,
            P.PowerDelta12Months,
            P.PowerDelta6Months,
            P.PowerDelta3Months,
            D.DEADS,
            D.StartingDEADS,
            D.OverallDEADSDelta,
            D.DEADSDelta12Months,
            D.DEADSDelta6Months,
            D.DEADSDelta3Months,
            ISNULL(H.HealedTroops, 0),
            ISNULL(H.StartingHealed, 0),
            ISNULL(H.OverallHealedDelta, 0),
            ISNULL(H.HealedDelta12Months, 0),
            ISNULL(H.HealedDelta6Months, 0),
            ISNULL(H.HealedDelta3Months, 0),
            ISNULL(R.RangedPoints, 0),
            ISNULL(R.StartingRanged, 0),
            ISNULL(R.OverallRangedDelta, 0),
            ISNULL(R.RangedDelta12Months, 0),
            ISNULL(R.RangedDelta6Months, 0),
            ISNULL(R.RangedDelta3Months, 0),
            ISNULL(KP.KillPoints, 0),
            ISNULL(KP.StartingKillPoints, 0),
            ISNULL(KP.OverallKillPointsDelta, 0),
            ISNULL(KP.KillPointsDelta12Months, 0),
            ISNULL(KP.KillPointsDelta6Months, 0),
            ISNULL(KP.KillPointsDelta3Months, 0)
        FROM dbo.POWERSUMMARY AS P
        INNER JOIN dbo.KILL4SUMMARY AS K4 ON P.GOVERNORID = K4.GOVERNORID
        INNER JOIN dbo.KILL5SUMMARY AS K5 ON P.GOVERNORID = K5.GOVERNORID
        INNER JOIN dbo.KILLSUMMARY AS K ON P.GOVERNORID = K.GOVERNORID
        INNER JOIN dbo.DEADSSUMMARY AS D ON P.GOVERNORID = D.GOVERNORID
        INNER JOIN dbo.HEALEDSUMMARY AS H ON P.GOVERNORID = H.GOVERNORID
        INNER JOIN dbo.RANGEDSUMMARY AS R ON P.GOVERNORID = R.GOVERNORID
        INNER JOIN dbo.KILLPOINTSSUMMARY AS KP ON P.GOVERNORID = KP.GOVERNORID
        ORDER BY P.GOVERNORNAME;

        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime)
        VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''SUMMARY_CHANGE_EXPORT'';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        DECLARE
            @ErrorMessage NVARCHAR(4000),
            @ErrorSeverity INT,
            @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END';
-- dbo.GOVERNOR_NAMES_PROC
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[GOVERNOR_NAMES_PROC]
WITH EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	-- REQUIRED SET options for DML against indexed views / computed columns / filtered indexes
	SET ANSI_NULLS ON;
	SET ANSI_PADDING ON;
	SET ANSI_WARNINGS ON;
	SET ARITHABORT ON;
	SET CONCAT_NULL_YIELDS_NULL ON;
	SET QUOTED_IDENTIFIER ON;
	SET NUMERIC_ROUNDABORT OFF;


    BEGIN TRY
        BEGIN TRANSACTION;

        ----------------------------------------------------------------
        -- Step 1: Truncate main target table
        ----------------------------------------------------------------
        TRUNCATE TABLE dbo.ALL_GOVS;

        ----------------------------------------------------------------
        -- Step 2: CTEs to prepare scan data (include CityHallLevel)
        ----------------------------------------------------------------
        WITH RankedScans AS (
            SELECT 
                GovernorID,
                GovernorName,
                NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), Alliance))), N'''') AS Alliance,
                ScanDate,
                [Power],
                KillPoints,
                Deads,
                T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
                TOTAL_KILLS,
                RSS_Gathered, RSSAssistance, Helps,

                -- new fields from KingdomScanData4 (point-in-time values)
                HealedTroops,
                RangedPoints,
                Civilization,
                KvKPlayed,
                MostKvKKill,
                MostKvKDead,
                MostKvKHeal,
                Acclaim,
                HighestAcclaim,
                AOOJoined,
                AOOWon,
                AOOAvgKill,
                AOOAvgDead,
                AOOAvgHeal,
                Conduct,

                -- ✅ City Hall level (confirm column name)
                [City Hall] AS CityHallLevel,

                ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY ScanOrder DESC) AS rn,
                MIN(ScanDate) OVER (PARTITION BY GovernorID) AS FirstScan,
                MAX([Power]) OVER (PARTITION BY GovernorID) AS MaxPower
            FROM dbo.KingdomScanData4
            WHERE GovernorID <> 0
        ),
        ScanData AS (
            SELECT 
                GovernorID,
                MAX(CASE WHEN rn = 1 THEN ScanDate END) AS LastScan,
                MAX(CASE WHEN rn = 2 THEN ScanDate END) AS PreviousScan,
                MAX(CASE WHEN rn = 1 THEN Power END) AS LatestPower,
                MAX(CASE WHEN rn = 1 THEN KillPoints END) AS KillPoints,
                MAX(CASE WHEN rn = 1 THEN Deads END) AS Deads,
                MAX(CASE WHEN rn = 1 THEN Helps END) AS Helps,
                MAX(CASE WHEN rn = 1 THEN RSS_Gathered END) AS RSS_GATHERED,
                MAX(CASE WHEN rn = 1 THEN RSSAssistance END) AS RSSASSISTANCE,
                MAX(CASE WHEN rn = 1 THEN GovernorName END) AS GovernorName,
                MAX(CASE WHEN rn = 1 THEN Alliance END) AS Alliance,
                MAX(CASE WHEN rn = 1 THEN T1_Kills END) AS T1_Kills,
                MAX(CASE WHEN rn = 1 THEN T2_Kills END) AS T2_Kills,
                MAX(CASE WHEN rn = 1 THEN T3_Kills END) AS T3_Kills,
                MAX(CASE WHEN rn = 1 THEN T4_Kills END) AS T4_Kills,
                MAX(CASE WHEN rn = 1 THEN T5_Kills END) AS T5_Kills,
                MAX(CASE WHEN rn = 1 THEN [T4&T5_KILLS] END) AS [T4&T5_KILLS],
                MAX(CASE WHEN rn = 1 THEN TOTAL_KILLS END) AS TOTAL_KILLS,
                MAX(FirstScan) AS FirstScan,
                MAX(MaxPower) AS MaxPower,

                -- new fields: take latest (rn = 1) values
                MAX(CASE WHEN rn = 1 THEN HealedTroops END)        AS HealedTroops,
                MAX(CASE WHEN rn = 1 THEN RangedPoints END)       AS RangedPoints,
                MAX(CASE WHEN rn = 1 THEN Civilization END)       AS Civilization,
                MAX(CASE WHEN rn = 1 THEN KvKPlayed END)          AS KvKPlayed,
                MAX(CASE WHEN rn = 1 THEN MostKvKKill END)        AS MostKvKKill,
                MAX(CASE WHEN rn = 1 THEN MostKvKDead END)        AS MostKvKDead,
                MAX(CASE WHEN rn = 1 THEN MostKvKHeal END)        AS MostKvKHeal,
                MAX(CASE WHEN rn = 1 THEN Acclaim END)            AS Acclaim,
                MAX(CASE WHEN rn = 1 THEN HighestAcclaim END)     AS HighestAcclaim,
                MAX(CASE WHEN rn = 1 THEN AOOJoined END)          AS AOOJoined,
                MAX(CASE WHEN rn = 1 THEN AOOWon END)             AS AOOWon,
                MAX(CASE WHEN rn = 1 THEN AOOAvgKill END)         AS AOOAvgKill,
                MAX(CASE WHEN rn = 1 THEN AOOAvgDead END)         AS AOOAvgDead,
                MAX(CASE WHEN rn = 1 THEN AOOAvgHeal END)         AS AOOAvgHeal,
                MAX(CASE WHEN rn = 1 THEN Conduct END)            AS Conduct,

                -- ✅ City Hall level
                MAX(CASE WHEN rn = 1 THEN CityHallLevel END)      AS CityHallLevel
            FROM RankedScans
            WHERE rn <= 2
            GROUP BY GovernorID
        )

        ----------------------------------------------------------------
        -- Step 3: Insert into ALL_GOVS including CityHallLevel
        ----------------------------------------------------------------
        INSERT INTO ALL_GOVS (
            GovernorID, GovernorName, [Max Power], [Latest Power],
            KillPoints, T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS],
            TOTAL_KILLS, Deads, Helps, RSS_Gathered, RSSAssistance,

            -- new fields (inserted before timestamps)
            HealedTroops, RangedPoints, Civilization, KvKPlayed,
            MostKvKKill, MostKvKDead, MostKvKHeal, Acclaim, HighestAcclaim,
            AOOJoined, AOOWon, AOOAvgKill, AOOAvgDead, AOOAvgHeal, Conduct,

            -- ✅ City Hall
            CityHallLevel,

            [Last Scan], [Previous Scan], [First Scan]
        )
        SELECT 
            s.GovernorID,
            RTRIM(s.GovernorName),
            s.MaxPower,
            s.LatestPower,
            s.KillPoints,
            s.T1_Kills, s.T2_Kills, s.T3_Kills, s.T4_Kills, s.T5_Kills, s.[T4&T5_KILLS],
            s.TOTAL_KILLS,
            s.Deads,
            s.Helps,
            s.RSS_GATHERED,
            s.RSSASSISTANCE,

            -- new fields selected from ScanData
            s.HealedTroops,
            s.RangedPoints,
            s.Civilization,
            s.KvKPlayed,
            s.MostKvKKill,
            s.MostKvKDead,
            s.MostKvKHeal,
            s.Acclaim,
            s.HighestAcclaim,
            s.AOOJoined,
            s.AOOWon,
            s.AOOAvgKill,
            s.AOOAvgDead,
            s.AOOAvgHeal,
            s.Conduct,

            -- ✅ City Hall
            s.CityHallLevel,

            s.LastScan,
            s.PreviousScan,
            s.FirstScan
        FROM ScanData s;

        ----------------------------------------------------------------
        -- Step 4: One deterministic spelling per existing collation-equivalent name
        ----------------------------------------------------------------
        TRUNCATE TABLE dbo.ALL_GOVS_NAMES;

        ;WITH NameCandidates AS (
            SELECT
                GovernorID,
                GovernorName,
                ROW_NUMBER() OVER (
                    PARTITION BY GovernorID, GovernorName
                    ORDER BY ScanOrder DESC,
                             GovernorName COLLATE Latin1_General_100_BIN2 ASC
                ) AS Representative
            FROM dbo.KingdomScanData4
            WHERE GovernorID <> 0 AND GovernorName IS NOT NULL
        )
        INSERT INTO ALL_GOVS_NAMES (GovernorID, GovernorName)
        SELECT GovernorID, RTRIM(GovernorName) AS GovernorName
        FROM NameCandidates
        WHERE Representative = 1;

        ----------------------------------------------------------------
        -- Step 5: Incremental refresh of Alliance history table
        -- Semantics retained: one row per unique (GovernorID, Alliance ever seen)
        ----------------------------------------------------------------

        IF NOT EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES_SYNC_STATE WHERE StateID = 1)
        BEGIN
            INSERT INTO dbo.ALL_GOVS_ALLIANCES_SYNC_STATE (StateID, LastProcessedScanOrder, LastProcessedScanDate, LastRunAt)
            SELECT
                1,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN ISNULL((SELECT MAX(kd4.SCANORDER) FROM dbo.KingdomScanData4 kd4 WHERE kd4.GovernorID <> 0), 0)
                    ELSE 0
                END,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN (SELECT MAX(kd4.ScanDate) FROM dbo.KingdomScanData4 kd4 WHERE kd4.GovernorID <> 0)
                    ELSE NULL
                END,
                CASE
                    WHEN EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
                        THEN GETDATE()
                    ELSE NULL
                END;
        END;

		DECLARE
            @LastProcessedScanOrder BIGINT,
            @CurrentMaxScanOrder BIGINT,
            @CurrentMaxScanDate DATETIME,
            @LastAllianceSyncRunAt DATETIME;

SELECT
            @LastProcessedScanOrder = LastProcessedScanOrder,
            @LastAllianceSyncRunAt = LastRunAt
        FROM dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
        WHERE StateID = 1;

        SELECT
            @CurrentMaxScanOrder = MAX(kd4.SCANORDER),
            @CurrentMaxScanDate = MAX(kd4.ScanDate)
        FROM dbo.KingdomScanData4 kd4
        WHERE kd4.GovernorID <> 0;

        -- Migration safety: if state was seeded as 0 but alliance history already exists,
        -- fast-forward watermark once to avoid reprocessing full history.
        IF ISNULL(@LastProcessedScanOrder, 0) = 0
           AND @LastAllianceSyncRunAt IS NULL
           AND EXISTS (SELECT 1 FROM dbo.ALL_GOVS_ALLIANCES)
           AND @CurrentMaxScanOrder IS NOT NULL
        BEGIN
            UPDATE dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
            SET LastProcessedScanOrder = @CurrentMaxScanOrder,
                LastProcessedScanDate = @CurrentMaxScanDate,
                LastRunAt = GETDATE()
            WHERE StateID = 1;

            SET @LastProcessedScanOrder = @CurrentMaxScanOrder;
        END;

        IF @CurrentMaxScanOrder IS NOT NULL
           AND @CurrentMaxScanOrder > ISNULL(@LastProcessedScanOrder, 0)
        BEGIN
            ;WITH CandidatePairs AS (
                SELECT
                    kd4.GovernorID,
                    NULLIF(LTRIM(RTRIM(CONVERT(nvarchar(255), kd4.Alliance))), N'''') AS Alliance
                FROM dbo.KingdomScanData4 kd4
                WHERE kd4.GovernorID <> 0
                  AND kd4.SCANORDER > ISNULL(@LastProcessedScanOrder, 0)
                  AND kd4.SCANORDER <= @CurrentMaxScanOrder
            ),
            DistinctPairs AS (
                SELECT
                    cp.GovernorID,
                    cp.Alliance
                FROM CandidatePairs cp
                WHERE cp.Alliance IS NOT NULL
                GROUP BY cp.GovernorID, cp.Alliance
            )
            INSERT INTO dbo.ALL_GOVS_ALLIANCES (GovernorID, Alliance)
            SELECT
                dp.GovernorID,
                dp.Alliance
            FROM DistinctPairs dp
            WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.ALL_GOVS_ALLIANCES aga
                WHERE aga.GovernorID = dp.GovernorID
                  AND aga.Alliance = dp.Alliance
            );

            UPDATE dbo.ALL_GOVS_ALLIANCES_SYNC_STATE
            SET LastProcessedScanOrder = @CurrentMaxScanOrder,
                LastProcessedScanDate = @CurrentMaxScanDate,
                LastRunAt = GETDATE()
            WHERE StateID = 1;
        END;


        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''ALL_GOVS'';
        COMMIT TRANSACTION;

    END TRY

	BEGIN CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;

		THROW;
	END CATCH
END;';
-- dbo.sp_RefreshInactiveGovernors
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_RefreshInactiveGovernors]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Optional: Log the start of execution
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, StartTime)
        VALUES (''sp_RefreshInactiveGovernors'', ''Started'', GETDATE());

        -- Step 1: Clear existing inactive governors
        TRUNCATE TABLE INACTIVE_GOVERNORS;

        -- Step 2: Insert new inactive governors
        INSERT INTO INACTIVE_GOVERNORS (GovernorID, GovernorName, [Power], Inactive_Date, [Status])
        SELECT 
            latest.GovernorID,
            RTRIM(ks.GovernorName) AS [GovernorName],
            ks.Power,
            ks.ScanDate AS Inactive_Date,
            ''Inactive / Migrated'' AS Status
        FROM (
            SELECT GovernorID, MAX(ScanDate) AS LastLogin
            FROM KingdomScanData4
            GROUP BY GovernorID
            HAVING MAX(ScanDate) <= DATEADD(DAY, -1, GETDATE())
               AND MAX(ScanDate) > DATEADD(DAY, -100, GETDATE())
        ) AS latest
        CROSS APPLY (
            SELECT TOP 1 RTRIM(GovernorName) AS GovernorName, Power, ScanDate
            FROM KingdomScanData4 k
            WHERE k.GovernorID = latest.GovernorID
              AND k.ScanDate = latest.LastLogin
            ORDER BY k.ScanDate DESC
        ) AS ks;

        -- Optional: Log success
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, EndTime)
        VALUES (''sp_RefreshInactiveGovernors'', ''Success'', GETDATE());

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''INACTIVE_GOVERNORS'';
        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        -- Rollback on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Log error if needed
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, ErrorMessage, EndTime)
        VALUES (
            ''sp_RefreshInactiveGovernors'',
            ''Error'',
            ERROR_MESSAGE(),
            GETDATE()
        );

        -- Optionally re-raise the error
        THROW;
    END CATCH
END;';
-- dbo.HEALEDSUMMARY_PROC_OPT
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[HEALEDSUMMARY_PROC_OPT]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @MetricName NVARCHAR(100) = N''HealedTroops'';
    DECLARE @LastProcessed INT = 0;
    DECLARE @MaxScan INT = 0;

    SELECT @LastProcessed = LastScanOrder
    FROM dbo.SUMMARY_PROC_STATE
    WHERE MetricName = @MetricName;

    IF @LastProcessed IS NULL SET @LastProcessed = 0;

    SELECT @MaxScan = ISNULL(MAX(ScanOrder), 0)
    FROM dbo.KingdomScanData4;

    IF @MaxScan <= @LastProcessed
    BEGIN
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        ------------------------------------------------------------
        -- Affected governors (typed as BIGINT to avoid implicit conversions)
        ------------------------------------------------------------
        CREATE TABLE #AffectedGovs
        (
            GovernorID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #AffectedGovs (GovernorID)
        SELECT DISTINCT ks4.GovernorID
        FROM dbo.KingdomScanData4 ks4
        WHERE ks4.ScanOrder > @LastProcessed
          AND ks4.GovernorID <> 0;

        IF NOT EXISTS (SELECT 1 FROM #AffectedGovs)
        BEGIN
            MERGE dbo.SUMMARY_PROC_STATE AS T
            USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
            ON T.MetricName = S.MetricName
            WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
            WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

            COMMIT;
            RETURN;
        END

        DECLARE @UtcNow DATETIME2(7) = SYSUTCDATETIME();
        DECLARE @Cutoff12 DATETIME2(7) = DATEADD(MONTH, -12, @UtcNow);
        DECLARE @Cutoff6 DATETIME2(7) = DATEADD(MONTH, -6, @UtcNow);
        DECLARE @Cutoff3 DATETIME2(7) = DATEADD(MONTH, -3, @UtcNow);

        ------------------------------------------------------------
        -- #GovScan with explicit types (avoid implicit conversions)
        ------------------------------------------------------------
        CREATE TABLE #GovScan
        (
            GovernorID   BIGINT       NOT NULL,
            GovernorName NVARCHAR(400) NULL,
            PowerRank    INT           NULL,
            ScanOrder    INT           NOT NULL,
            ScanDate     DATETIME      NULL,
            HealedTroops BIGINT        NULL
        );

        INSERT INTO #GovScan (GovernorID, GovernorName, PowerRank, ScanOrder, ScanDate, HealedTroops)
        SELECT
            ks4.GovernorID,
            CONVERT(NVARCHAR(400), ks4.GovernorName) AS GovernorName,
            ks4.PowerRank,
            ks4.ScanOrder,
            ks4.ScanDate,
            ks4.HealedTroops
        FROM dbo.KingdomScanData4 ks4
        INNER JOIN #AffectedGovs a ON a.GovernorID = ks4.GovernorID;

        CREATE CLUSTERED INDEX IX_GovScan_GovernorID_ScanOrder ON #GovScan (GovernorID, ScanOrder);
        CREATE NONCLUSTERED INDEX IX_GovScan_ScanDate_GovernorID ON #GovScan (ScanDate, GovernorID) INCLUDE (ScanOrder);

        ------------------------------------------------------------
        -- 1) HEALED_ALL: Delete and rebuild for affected governors
        ------------------------------------------------------------
        -- Retain only first/last rows; use exact count/ID types and preserve ranking.
        CREATE TABLE #P021_HEALED_ALL(
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAscALL] [int] NULL,
	[RowDescALL] [int] NULL
        );

        ;WITH RankedAll AS (
            SELECT
                g.GovernorID,
                g.GovernorName,
                g.HealedTroops,
                g.ScanDate,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC)  AS RowAscALL,
                ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder DESC) AS RowDescALL
            FROM #GovScan g
        )
        INSERT INTO #P021_HEALED_ALL (GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL)
        SELECT GovernorID, GovernorName, HealedTroops, ScanDate, RowAscALL, RowDescALL
        FROM RankedAll
        WHERE RowAscALL = 1 OR RowDescALL = 1;

        ------------------------------------------------------------
        -- Remaining sections unchanged (D12/D6/D3/etc.)
        ------------------------------------------------------------
        -- Retain only first/last rows; use exact count/ID types and preserve ranking.
        CREATE TABLE #P021_HEALED_D12(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc12] [int] NULL,
	[RowDesc12] [int] NULL
        );

        ;WITH RankedD12 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc12,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc12
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff12
        )
        INSERT INTO #P021_HEALED_D12 (GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc12, RowDesc12
        FROM RankedD12
        WHERE RowAsc12 = 1 OR RowDesc12 = 1;

        -- Retain only first/last rows; use exact count/ID types and preserve ranking.
        CREATE TABLE #P021_HEALED_D6(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc6] [int] NULL,
	[RowDesc6] [int] NULL
        );

        ;WITH RankedD6 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc6,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc6
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff6
        )
        INSERT INTO #P021_HEALED_D6 (GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc6, RowDesc6
        FROM RankedD6
        WHERE RowAsc6 = 1 OR RowDesc6 = 1;

        -- Retain only first/last rows; use exact count/ID types and preserve ranking.
        CREATE TABLE #P021_HEALED_D3(
	[GovernorID] [bigint] NOT NULL,
	[HealedTroops] [bigint] NULL,
	[ScanDate] [datetime] NULL,
	[RowAsc3] [int] NULL,
	[RowDesc3] [int] NULL
        );

        ;WITH RankedD3 AS (
            SELECT g.GovernorID,
                   g.HealedTroops,
                   g.ScanDate,
                   ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) AS RowAsc3,
                   COUNT_BIG(*) OVER (PARTITION BY g.GovernorID) - ROW_NUMBER() OVER (PARTITION BY g.GovernorID ORDER BY g.ScanOrder ASC) + 1 AS RowDesc3
            FROM #GovScan g
            WHERE g.ScanDate >= @Cutoff3
        )
        INSERT INTO #P021_HEALED_D3 (GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3)
        SELECT GovernorID, HealedTroops, ScanDate, RowAsc3, RowDesc3
        FROM RankedD3
        WHERE RowAsc3 = 1 OR RowDesc3 = 1;

        ;WITH LatestScanOrder AS (
            SELECT g.GovernorID, MAX(g.ScanOrder) AS LatestScanOrder
            FROM #GovScan g
            GROUP BY g.GovernorID
        )
        MERGE dbo.HEALED_LATEST AS tgt
        USING (
            SELECT g.GovernorID, g.GovernorName, g.PowerRank, g.HealedTroops
            FROM #GovScan g
            INNER JOIN LatestScanOrder l
                ON l.GovernorID = g.GovernorID
               AND l.LatestScanOrder = g.ScanOrder
        ) AS src
        ON tgt.GovernorID = src.GovernorID
        WHEN MATCHED THEN
            UPDATE SET GovernorName = src.GovernorName, PowerRank = src.PowerRank, HealedTroops = src.HealedTroops
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops)
            VALUES (src.GovernorID, src.GovernorName, src.PowerRank, src.HealedTroops);

        DELETE d
        FROM dbo.HEALED_D3D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D3D (GovernorID, HealedTroopsDelta3Months)
        SELECT L.GovernorID,
               CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowDesc3 = 1 THEN D3.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D3.RowAsc3 = 1 THEN D3.HealedTroops END))
        FROM dbo.HEALED_LATEST L
        LEFT JOIN #P021_HEALED_D3 D3 ON L.GovernorID = D3.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D6D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D6D (GovernorID, HealedTroopsDelta6Months)
        SELECT L.GovernorID,
               CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowDesc6 = 1 THEN D6.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D6.RowAsc6 = 1 THEN D6.HealedTroops END))
        FROM dbo.HEALED_LATEST L
        LEFT JOIN #P021_HEALED_D6 D6 ON L.GovernorID = D6.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        DELETE d
        FROM dbo.HEALED_D12D d
        INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID;

        INSERT INTO dbo.HEALED_D12D (GovernorID, HealedTroopsDelta12Months)
        SELECT L.GovernorID,
               CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowDesc12 = 1 THEN D12.HealedTroops END)) - CONVERT(decimal(38,0), MAX(CASE WHEN D12.RowAsc12 = 1 THEN D12.HealedTroops END))
        FROM dbo.HEALED_LATEST L
        LEFT JOIN #P021_HEALED_D12 D12 ON L.GovernorID = D12.GovernorID
        INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        GROUP BY L.GovernorID;

        ;WITH FirstLastAll AS (
            SELECT d.GovernorID,
                   MAX(CASE WHEN d.RowAscALL = 1 THEN d.HealedTroops END) AS StartingHealed,
                   MAX(CASE WHEN d.RowDescALL = 1 THEN d.HealedTroops END) AS EndingHealed
            FROM #P021_HEALED_ALL d
            INNER JOIN #AffectedGovs a ON a.GovernorID = d.GovernorID
            GROUP BY d.GovernorID
        ),
        Source AS (
            SELECT
                L.GovernorID,
                L.GovernorName,
                L.PowerRank,
                L.HealedTroops,
                F.StartingHealed,
                CONVERT(decimal(38,0), F.EndingHealed) - CONVERT(decimal(38,0), F.StartingHealed) AS OverallHealedDelta,
                ISNULL(D12D.HealedTroopsDelta12Months, 0) AS HealedDelta12Months,
                ISNULL(D6D.HealedTroopsDelta6Months, 0) AS HealedDelta6Months,
                ISNULL(D3D.HealedTroopsDelta3Months, 0) AS HealedDelta3Months
            FROM dbo.HEALED_LATEST L
            INNER JOIN FirstLastAll F ON L.GovernorID = F.GovernorID
            LEFT JOIN dbo.HEALED_D12D D12D ON L.GovernorID = D12D.GovernorID
            LEFT JOIN dbo.HEALED_D6D D6D ON L.GovernorID = D6D.GovernorID
            LEFT JOIN dbo.HEALED_D3D D3D ON L.GovernorID = D3D.GovernorID
            INNER JOIN #AffectedGovs a ON a.GovernorID = L.GovernorID
        )
        MERGE dbo.HEALEDSUMMARY AS T
        USING Source AS S
        ON T.GovernorID = S.GovernorID
        WHEN MATCHED THEN
            UPDATE SET
                GovernorName = S.GovernorName,
                PowerRank = S.PowerRank,
                HealedTroops = S.HealedTroops,
                StartingHealed = S.StartingHealed,
                OverallHealedDelta = S.OverallHealedDelta,
                HealedDelta12Months = S.HealedDelta12Months,
                HealedDelta6Months = S.HealedDelta6Months,
                HealedDelta3Months = S.HealedDelta3Months
        WHEN NOT MATCHED THEN
            INSERT (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
            VALUES (S.GovernorID, S.GovernorName, S.PowerRank, S.HealedTroops, S.StartingHealed, S.OverallHealedDelta, S.HealedDelta12Months, S.HealedDelta6Months, S.HealedDelta3Months);

        DELETE FROM dbo.HEALEDSUMMARY WHERE GovernorID IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999997, ''Top50'', 50,
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 50
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999998, ''Top100'', 100,
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 100
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        INSERT INTO dbo.HEALEDSUMMARY (GovernorID, GovernorName, PowerRank, HealedTroops, StartingHealed, OverallHealedDelta, HealedDelta12Months, HealedDelta6Months, HealedDelta3Months)
        SELECT 999999999, ''Kingdom Average'', 150,
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedTroops)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.StartingHealed)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.OverallHealedDelta)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta12Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta6Months)), 0),
               ROUND(AVG(CONVERT(decimal(38,6), H.HealedDelta3Months)), 0)
        FROM dbo.HEALEDSUMMARY AS H
        WHERE H.PowerRank <= 150
          AND H.GovernorID NOT IN (999999997, 999999998, 999999999);

        MERGE dbo.SUMMARY_PROC_STATE AS T
        USING (SELECT @MetricName AS MetricName, @MaxScan AS LastScanOrder, SYSUTCDATETIME() AS LastRunTime) AS S
        ON T.MetricName = S.MetricName
        WHEN MATCHED THEN UPDATE SET LastScanOrder = S.LastScanOrder, LastRunTime = S.LastRunTime
        WHEN NOT MATCHED THEN INSERT (MetricName, LastScanOrder, LastRunTime) VALUES (S.MetricName, S.LastScanOrder, S.LastRunTime);

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''HEALEDSUMMARY'';
        COMMIT;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK;
        DECLARE @ErrMsg NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(''HEALEDSUMMARY_PROC_OPT failed: %s'', 16, 1, @ErrMsg);
        RETURN;
    END CATCH
END';
-- dbo.SP_Stats_for_Upload
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[SP_Stats_for_Upload]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @LatestKVK int,
        @MaxScan int,
        @KvkEndScanValue float,
        @KvkEndScan int,
        @ExpectedFinalScan int,
        @ProvenFinalScan int,
        @HeaderRowCount int,
        @HeaderRevision int,
        @HeaderState nvarchar(24),
        @FinalizationBasis nvarchar(24),
        @FinalDataAtUtc datetime2(0),
        @CurrentHeaderScan int,
        @CurrentHeaderRowCount int,
        @CurrentHeaderRevision int,
        @CurrentHeaderState nvarchar(24),
        @SourceRowCount bigint = 0,
        @InvalidGovernorRows bigint = 0,
        @DuplicateGovernorGroups bigint = 0,
        @WrongKvkRows bigint = 0,
        @CandidateRowCount bigint = 0,
        @PublishedRowCount bigint = 0,
        @ProvenScanDate datetime2(0),
        @ProvenScanDateMax datetime2(0),
        @ScanDateRowCount bigint = 0,
        @TableName sysname,
        @TableObjectName nvarchar(260),
        @TableNameFull nvarchar(260),
        @sql nvarchar(max),
        @Diagnostic nvarchar(2048),
        @FailureStage nvarchar(64) = N''preflight'',
        @ImportLockResult int,
        @LockResult int,
        @InitialTranCount int = @@TRANCOUNT,
        @StartedTransaction bit = 0,
        @SavepointCreated bit = 0;

    BEGIN TRY
        IF @InitialTranCount = 0
        BEGIN
            BEGIN TRANSACTION;
            SET @StartedTransaction = 1;
        END
        ELSE
        BEGIN
            SAVE TRANSACTION StatsForUploadPublishSave;
            SET @SavepointCreated = 1;
        END;

        SET @FailureStage = N''import-lock'';
        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 52820, ''SP_Stats_for_Upload: KS4 import lock could not be acquired.'', 1;

        SET @FailureStage = N''publication-lock'';
        EXEC @LockResult = sys.sp_getapplock
            @Resource = N''K98:StatsForUpload:Publish'',
            @LockMode = N''Exclusive'',
            @LockOwner = N''Transaction'',
            @LockTimeout = 60000,
            @DbPrincipal = N''public'';

        IF @LockResult < 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: publication lock failed; lock result='', @LockResult, ''.''
            );
            THROW 52803, @Diagnostic, 1;
        END;

        SET @FailureStage = N''eligibility-snapshot'';
        SELECT @MaxScan = MAX(SCANORDER)
        FROM dbo.KingdomScanData4 WITH (UPDLOCK, HOLDLOCK);

        IF @MaxScan IS NULL
            THROW 52800, ''SP_Stats_for_Upload: no scan data is available.'', 1;

        SELECT TOP (1) @LatestKVK = KVKVersion
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CONVERT(int, ConfigValue) IS NOT NULL
          AND ConfigValue = CONVERT(float, TRY_CONVERT(int, ConfigValue))
          AND TRY_CONVERT(int, ConfigValue) <= @MaxScan
        ORDER BY KVKVersion DESC;

        IF @LatestKVK IS NULL OR @LatestKVK <= 0 OR @LatestKVK > 2147483647
            THROW 52801, ''SP_Stats_for_Upload: no valid eligible KVK was found.'', 1;

        SELECT @KvkEndScanValue = ConfigValue
        FROM dbo.ProcConfig WITH (UPDLOCK, HOLDLOCK)
        WHERE KVKVersion = CONVERT(int, @LatestKVK)
          AND ConfigKey = ''KVK_END_SCAN'';

        SET @KvkEndScan = TRY_CONVERT(int, @KvkEndScanValue);

        IF @KvkEndScan IS NULL
           OR @KvkEndScan <= 0
           OR @KvkEndScanValue <> CONVERT(float, @KvkEndScan)
            THROW 52802, ''SP_Stats_for_Upload: KVK_END_SCAN is missing or is not a positive integral scan.'', 1;

        SET @ExpectedFinalScan = CASE
            WHEN @MaxScan > @KvkEndScan THEN @KvkEndScan
            ELSE @MaxScan
        END;

        SET @FailureStage = N''header-preflight'';
        SELECT
            @ProvenFinalScan = FinalScanOrder,
            @HeaderRowCount = OutputRowCount,
            @HeaderRevision = Revision,
            @HeaderState = State,
            @FinalizationBasis = FinalizationBasis,
            @FinalDataAtUtc = FinalDataAtUtc
        FROM dbo.KVKFinalReportHeader
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @ProvenFinalScan IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: missing output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52804, @Diagnostic, 1;
        END;

        IF @HeaderState <> N''OUTPUT_COMPLETE''
           OR @HeaderRevision IS NULL OR @HeaderRevision <= 0
           OR @HeaderRowCount IS NULL OR @HeaderRowCount <= 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid output header for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
                '', revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''), ''.''
            );
            THROW 52805, @Diagnostic, 1;
        END;

        IF @ProvenFinalScan <> @ExpectedFinalScan
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: stale output for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', proven scan='', @ProvenFinalScan,
                '', revision='', @HeaderRevision, ''.''
            );
            THROW 52806, @Diagnostic, 1;
        END;

        SET @TableName = N''EXCEL_FOR_KVK_'' + CONVERT(nvarchar(20), @LatestKVK);
        SET @TableObjectName = N''dbo.'' + @TableName;
        SET @TableNameFull = QUOTENAME(N''dbo'') + N''.'' + QUOTENAME(@TableName);

        IF OBJECT_ID(@TableObjectName, N''U'') IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source object '', @TableObjectName,
                '' is missing for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan, ''.''
            );
            THROW 52807, @Diagnostic, 1;
        END;

        SET @FailureStage = N''scan-date'';
        SELECT
            @ScanDateRowCount = COUNT_BIG(*),
            @ProvenScanDate = MIN(CONVERT(datetime2(0), ScanDate)),
            @ProvenScanDateMax = MAX(CONVERT(datetime2(0), ScanDate))
        FROM dbo.KingdomScanData4
        WHERE SCANORDER = @ProvenFinalScan;

        IF @ScanDateRowCount <= 0 OR @ProvenScanDate IS NULL
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is missing for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52808, @Diagnostic, 1;
        END;

        IF @ProvenScanDate <> @ProvenScanDateMax
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source scan date is inconsistent for KVK='', @LatestKVK,
                '', proven scan='', @ProvenFinalScan, ''.''
            );
            THROW 52809, @Diagnostic, 1;
        END;

        SET @FailureStage = N''source-shape'';
        SET @sql = N''
            SELECT
                @pSourceRowCount = COUNT_BIG(*),
                @pInvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0 THEN 1 ELSE 0 END)), 0),
                @pWrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                    WHEN TRY_CONVERT(int, [KVK_NO]) <> @pLatestKVK
                      OR [KVK_NO] IS NULL THEN 1 ELSE 0 END)), 0)
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);

            SELECT @pDuplicateGovernorGroups = COUNT_BIG(*)
            FROM
            (
                SELECT TRY_CONVERT(bigint, [Gov_ID]) AS GovernorID
                FROM '' + @TableNameFull + N'' WITH (HOLDLOCK)
                GROUP BY TRY_CONVERT(bigint, [Gov_ID])
                HAVING COUNT_BIG(*) > 1
            ) AS duplicates;'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pSourceRowCount bigint OUTPUT, @pInvalidGovernorRows bigint OUTPUT, @pWrongKvkRows bigint OUTPUT, @pDuplicateGovernorGroups bigint OUTPUT'',
            @pLatestKVK = @LatestKVK,
            @pSourceRowCount = @SourceRowCount OUTPUT,
            @pInvalidGovernorRows = @InvalidGovernorRows OUTPUT,
            @pWrongKvkRows = @WrongKvkRows OUTPUT,
            @pDuplicateGovernorGroups = @DuplicateGovernorGroups OUTPUT;

        IF @SourceRowCount <= 0
            THROW 52810, ''SP_Stats_for_Upload: proven source output contains no rows.'', 1;

        IF @SourceRowCount <> @HeaderRowCount
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: source/header row-count mismatch for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', revision='', @HeaderRevision,
                '', header rows='', @HeaderRowCount,
                '', source rows='', @SourceRowCount, ''.''
            );
            THROW 52811, @Diagnostic, 1;
        END;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: invalid source identity for KVK='', @LatestKVK,
                '', invalid governors='', @InvalidGovernorRows,
                '', duplicate governor groups='', @DuplicateGovernorGroups,
                '', wrong KVK rows='', @WrongKvkRows, ''.''
            );
            THROW 52812, @Diagnostic, 1;
        END;

        SET @FailureStage = N''candidate-build'';
        SELECT TOP (0) *
        INTO #StatsForUploadCandidate
        FROM dbo.STATS_FOR_UPLOAD;

        SET @sql = N''
            INSERT INTO #StatsForUploadCandidate
            (
                [Rank],[KVK_RANK],[Gov_ID],[Governor_Name],
                [Starting Power],[Power_Delta],
                [Civilization],[KvKPlayed],[MostKvKKill],[MostKvKDead],[MostKvKHeal],
                [Acclaim],[HighestAcclaim],[AOOJoined],[AOOWon],[AOOAvgKill],[AOOAvgDead],[AOOAvgHeal],[Conduct],
                [Starting_T4&T5_KILLS],[T4_KILLS],[T5_KILLS],[T4&T5_Kills],[KILLS_OUTSIDE_KVK],[Kill Target],[% of Kill Target],
                [Starting_Deads],[Deads_Delta],[DEADS_OUTSIDE_KVK],[T4_Deads],[T5_Deads],[Dead_Target],[% of Dead Target],
                [Zeroed],[DKP_SCORE],[DKP Target],[% of DKP Target],
                [HelpsDelta],[RSS_Assist_Delta],[RSS_Gathered_Delta],
                [Pass 4 Kills],[Pass 6 Kills],[Pass 7 Kills],[Pass 8 Kills],
                [Pass 4 Deads],[Pass 6 Deads],[Pass 7 Deads],[Pass 8 Deads],
                [Starting_HealedTroops],[HealedTroopsDelta],
                [Starting_KillPoints],[KillPointsDelta],
                [RangedPoints],[RangedPointsDelta],[AutarchTimes],
                [Max_PreKvk_Points],[Max_HonorPoints],[PreKvk_Rank],[Honor_Rank],
                [KVK_NO],[LAST_REFRESH],[STATUS]
            )
            SELECT
                [Rank], [KVK_RANK], CAST([Gov_ID] AS bigint), RTRIM([Governor_Name]),
                [Starting Power], ISNULL([Power_Delta], 0),
                [Civilization], ISNULL([KvKPlayed], 0), ISNULL([MostKvKKill], 0),
                ISNULL([MostKvKDead], 0), ISNULL([MostKvKHeal], 0),
                ISNULL([Acclaim], 0), ISNULL([HighestAcclaim], 0), ISNULL([AOOJoined], 0),
                ISNULL([AOOWon], 0), ISNULL([AOOAvgKill], 0), ISNULL([AOOAvgDead], 0),
                ISNULL([AOOAvgHeal], 0), [Conduct],
                ISNULL([Starting_T4&T5_KILLS], 0), ISNULL([T4_KILLS], 0),
                ISNULL([T5_KILLS], 0), ISNULL([T4&T5_Kills], 0), ISNULL([KILLS_OUTSIDE_KVK], 0),
                ISNULL([Kill Target], 0), ISNULL([% of Kill Target], 0),
                ISNULL([Starting_Deads], 0), ISNULL([Deads_Delta], 0),
                ISNULL([DEADS_OUTSIDE_KVK], 0), ISNULL([T4_Deads], 0), ISNULL([T5_Deads], 0),
                ISNULL([Dead_Target], 0), ISNULL([% of Dead Target], 0),
                ISNULL([Zeroed], 0), ISNULL([DKP_SCORE], 0), ISNULL([DKP Target], 0),
                ISNULL([% of DKP Target], 0), ISNULL([HelpsDelta], 0),
                ISNULL([RSS_Assist_Delta], 0), ISNULL([RSS_Gathered_Delta], 0),
                ISNULL([Pass 4 Kills], 0), ISNULL([Pass 6 Kills], 0),
                ISNULL([Pass 7 Kills], 0), ISNULL([Pass 8 Kills], 0),
                ISNULL([Pass 4 Deads], 0), ISNULL([Pass 6 Deads], 0),
                ISNULL([Pass 7 Deads], 0), ISNULL([Pass 8 Deads], 0),
                ISNULL([Starting_HealedTroops], 0), ISNULL([HealedTroopsDelta], 0),
                ISNULL([Starting_KillPoints], 0), ISNULL([KillPointsDelta], 0),
                ISNULL([RangedPoints], 0), ISNULL([RangedPointsDelta], 0), ISNULL([AutarchTimes], 0),
                ISNULL([Max_PreKvk_Points], 0), ISNULL([Max_HonorPoints], 0),
                ISNULL([PreKvk_Rank], 0), ISNULL([Honor_Rank], 0),
                [KVK_NO], @pProvenScanDate,
                CASE
                    WHEN CAST([Gov_ID] AS bigint) IN
                    (
                        SELECT GovernorID
                        FROM dbo.EXEMPT_FROM_STATS
                        WHERE KVK_NO IN (0, @pLatestKVK)
                    ) THEN N''''EXEMPT''''
                    ELSE N''''INCLUDED''''
                END
            FROM '' + @TableNameFull + N'' WITH (HOLDLOCK);'';

        EXEC sys.sp_executesql
            @sql,
            N''@pLatestKVK int, @pProvenScanDate datetime2(0)'',
            @pLatestKVK = @LatestKVK,
            @pProvenScanDate = @ProvenScanDate;

        SELECT
            @CandidateRowCount = COUNT_BIG(*),
            @InvalidGovernorRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN Gov_ID IS NULL OR Gov_ID <= 0 THEN 1 ELSE 0 END)), 0),
            @WrongKvkRows = COALESCE(SUM(CONVERT(bigint, CASE
                WHEN KVK_NO <> CONVERT(int, @LatestKVK) OR KVK_NO IS NULL THEN 1 ELSE 0 END)), 0)
        FROM #StatsForUploadCandidate;

        SELECT @DuplicateGovernorGroups = COUNT_BIG(*)
        FROM
        (
            SELECT Gov_ID
            FROM #StatsForUploadCandidate
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        ) AS duplicates;

        IF @CandidateRowCount <= 0 OR @CandidateRowCount <> @SourceRowCount
            THROW 52813, ''SP_Stats_for_Upload: candidate row count does not match the proven source.'', 1;

        IF @InvalidGovernorRows > 0 OR @DuplicateGovernorGroups > 0 OR @WrongKvkRows > 0
            THROW 52814, ''SP_Stats_for_Upload: candidate identity validation failed.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM #StatsForUploadCandidate
            WHERE LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
            THROW 52815, ''SP_Stats_for_Upload: candidate LAST_REFRESH is not coherent with the proven scan.'', 1;

        SET @FailureStage = N''header-recheck'';
        SELECT
            @CurrentHeaderScan = FinalScanOrder,
            @CurrentHeaderRowCount = OutputRowCount,
            @CurrentHeaderRevision = Revision,
            @CurrentHeaderState = State
        FROM dbo.KVKFinalReportHeader WITH (UPDLOCK, HOLDLOCK)
        WHERE KVK_NO = CONVERT(int, @LatestKVK);

        IF @CurrentHeaderScan IS NULL
           OR @CurrentHeaderRowCount IS NULL
           OR @CurrentHeaderRevision IS NULL
           OR @CurrentHeaderState IS NULL
           OR @CurrentHeaderScan <> @ProvenFinalScan
           OR @CurrentHeaderRowCount <> @HeaderRowCount
           OR @CurrentHeaderRevision <> @HeaderRevision
           OR @CurrentHeaderState <> @HeaderState
        BEGIN
            SET @Diagnostic = CONCAT(
                ''SP_Stats_for_Upload: output provenance changed during publication for KVK='', @LatestKVK,
                '', expected scan='', @ExpectedFinalScan,
                '', initial revision='', @HeaderRevision,
                '', current revision='', COALESCE(CONVERT(varchar(20), @CurrentHeaderRevision), ''NULL''), ''.''
            );
            THROW 52816, @Diagnostic, 1;
        END;

        SET @FailureStage = N''target-replacement'';
        DELETE FROM dbo.STATS_FOR_UPLOAD;

        INSERT INTO dbo.STATS_FOR_UPLOAD
        SELECT *
        FROM #StatsForUploadCandidate;

        SET @PublishedRowCount = @@ROWCOUNT;

        IF @PublishedRowCount <> @CandidateRowCount
            THROW 52817, ''SP_Stats_for_Upload: published row count does not match the validated candidate.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.STATS_FOR_UPLOAD
            WHERE Gov_ID IS NULL OR Gov_ID <= 0
               OR KVK_NO IS NULL OR KVK_NO <> CONVERT(int, @LatestKVK)
               OR LAST_REFRESH IS NULL OR LAST_REFRESH <> @ProvenScanDate
        )
        OR EXISTS
        (
            SELECT Gov_ID
            FROM dbo.STATS_FOR_UPLOAD
            GROUP BY Gov_ID
            HAVING COUNT_BIG(*) > 1
        )
            THROW 52818, ''SP_Stats_for_Upload: post-publication row-shape validation failed.'', 1;

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''STATS_FOR_UPLOAD'';
        SET @FailureStage = N''target-statistics'';
        UPDATE STATISTICS dbo.STATS_FOR_UPLOAD WITH FULLSCAN;

        IF @StartedTransaction = 1
            COMMIT TRANSACTION;

        PRINT CONCAT(
            ''SP_Stats_for_Upload: completed KVK='', @LatestKVK,
            '', expected scan='', @ExpectedFinalScan,
            '', proven scan='', @ProvenFinalScan,
            '', header revision='', @HeaderRevision,
            '', basis='', @FinalizationBasis,
            '', generated at='', CONVERT(varchar(19), @FinalDataAtUtc, 120),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', source scan date='', CONVERT(varchar(19), @ProvenScanDate, 120), ''.''
        );
    END TRY
    BEGIN CATCH
        DECLARE @ErrorNumber int = ERROR_NUMBER();
        DECLARE @ErrorMessage nvarchar(2048) = ERROR_MESSAGE();

        IF @StartedTransaction = 1 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @SavepointCreated = 1 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION StatsForUploadPublishSave;

        IF @ErrorNumber BETWEEN 52800 AND 52820
            THROW;

        SET @Diagnostic = CONCAT(
            ''SP_Stats_for_Upload: failed at stage='', @FailureStage,
            '', KVK='', COALESCE(CONVERT(varchar(20), @LatestKVK), ''NULL''),
            '', expected scan='', COALESCE(CONVERT(varchar(20), @ExpectedFinalScan), ''NULL''),
            '', proven scan='', COALESCE(CONVERT(varchar(20), @ProvenFinalScan), ''NULL''),
            '', header revision='', COALESCE(CONVERT(varchar(20), @HeaderRevision), ''NULL''),
            '', source rows='', @SourceRowCount,
            '', published rows='', @PublishedRowCount,
            '', SQL error='', @ErrorNumber,
            '', detail='', LEFT(@ErrorMessage, 600), ''.''
        );
        THROW 52819, @Diagnostic, 1;
    END CATCH;
END';
-- dbo.CREATE_DASH2
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[CREATE_DASH2]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON; -- Ensure transaction rollback on error

    -- Clear target table
    TRUNCATE TABLE dbo.DASH;

    ----------------------------------------------------------------
    -- Step 1: Create #RankingGroups temp table
    -- Optimization: Use VALUES constructor instead of UNION ALL
    ----------------------------------------------------------------
    IF OBJECT_ID(''tempdb..#RankingGroups'') IS NOT NULL DROP TABLE #RankingGroups;

    SELECT DISTINCT 
        KVK_NO, 
        RankGroup, 
        KVK_Rank_Max
    INTO #RankingGroups
    FROM (
        SELECT DISTINCT
            ed.KVK_NO,
            v.RankGroup,
            v.KVK_Rank_Max
        FROM dbo.EXCEL_FOR_DASHBOARD ed
        CROSS APPLY (
            VALUES 
                (''50'', 50),
                (''100'', 100),
                (''150'', 150)
        ) v(RankGroup, KVK_Rank_Max)
    ) AS t;

    -- Optimization: Add index on temp table for better join performance
    CREATE CLUSTERED INDEX IX_RankingGroups ON #RankingGroups(KVK_NO, RankGroup, KVK_Rank_Max);

    ----------------------------------------------------------------
    -- Step 2: Create #Aggregated temp table (compute averages)
    -- Optimization: Removed redundant CAST to FLOAT, simplified expressions
    ----------------------------------------------------------------
    IF OBJECT_ID(''tempdb..#Aggregated'') IS NOT NULL DROP TABLE #Aggregated;

    SELECT
        rg.RankGroup AS [RANK],
        rg.RankGroup AS [KVK_RANK],
        CASE rg.RankGroup
            WHEN ''50''  THEN ''999999997''
            WHEN ''100'' THEN ''999999998''
            WHEN ''150'' THEN ''999999999''
        END AS [Gov_ID],
        CASE rg.RankGroup
            WHEN ''50''  THEN ''Top50''
            WHEN ''100'' THEN ''Top100''
            WHEN ''150'' THEN ''Kingdom Average''
        END AS [Governor_Name],

        -- Power metrics
        ROUND(AVG(CAST(ed.[Starting Power] AS FLOAT)), 0) AS [Starting Power],
        ROUND(AVG(CAST(ed.[Power_Delta] AS FLOAT)), 0) AS [POWER_DELTA],

        -- Kill metrics
        ROUND(AVG(CAST(ed.[T4_KILLS] AS FLOAT)), 0) AS [T4_KILLS],
        ROUND(AVG(CAST(ed.[T5_KILLS] AS FLOAT)), 0) AS [T5_KILLS],
        ROUND(AVG(CAST(ed.[T4&T5_Kills] AS FLOAT)), 0) AS [T4&T5_Kills],
        ROUND(AVG(CAST(ed.[Starting_T4&T5_KILLS] AS FLOAT)), 0) AS [Starting T4&T5_KILLS],
        ROUND(AVG(CAST(ed.[KILLS_OUTSIDE_KVK] AS FLOAT)), 0) AS [KILLS_OUTSIDE_KVK],

        -- Kill targets
        ROUND(AVG(CAST(ed.[Kill Target] AS FLOAT)), 0) AS [Kill Target],
        ROUND(AVG(CAST(ed.[% of Kill Target] AS FLOAT)), 2) AS [% of Kill target],

        -- Dead metrics (compute current Deads as Starting_Deads + Deads_Delta)
        ROUND(AVG(CAST(ISNULL(ed.[Starting_Deads], 0) + ISNULL(ed.[Deads_Delta], 0) AS FLOAT)), 0) AS [Deads],
        ROUND(AVG(CAST(ed.[T4_Deads] AS FLOAT)), 0) AS [T4_Deads],
        ROUND(AVG(CAST(ed.[T5_Deads] AS FLOAT)), 0) AS [T5_Deads],
        ROUND(AVG(CAST(ed.[Starting_Deads] AS FLOAT)), 0) AS [Starting Deads],
        ROUND(AVG(CAST(ed.[DEADS_OUTSIDE_KVK] AS FLOAT)), 0) AS [DEADS_OUTSIDE_KVK],

        -- Dead targets
        ROUND(AVG(CAST(ed.[Dead_Target] AS FLOAT)), 0) AS [Dead_Target],
        ROUND(AVG(CAST(ed.[% of Dead Target] AS FLOAT)), 2) AS [% of Dead_Target],

        -- Zeroed status (use MAX for aggregation)
        MAX(CAST(ISNULL(ed.[Zeroed], 0) AS INT)) AS [Zeroed],

        -- DKP metrics
        ROUND(AVG(CAST(ed.[DKP_SCORE] AS FLOAT)), 0) AS [DKP_Score],
        ROUND(AVG(CAST(ed.[DKP Target] AS FLOAT)), 0) AS [DKP Target],
        ROUND(AVG(CAST(ed.[% of DKP Target] AS FLOAT)), 2) AS [% of DKP Target],

        -- Pass kills
        ROUND(AVG(CAST(ed.[Pass 4 Kills] AS FLOAT)), 0) AS [Pass 4 Kills],
        ROUND(AVG(CAST(ed.[Pass 6 Kills] AS FLOAT)), 0) AS [Pass 6 Kills],
        ROUND(AVG(CAST(ed.[Pass 7 Kills] AS FLOAT)), 0) AS [Pass 7 Kills],
        ROUND(AVG(CAST(ed.[Pass 8 Kills] AS FLOAT)), 0) AS [Pass 8 Kills],

        -- Pass deads
        ROUND(AVG(CAST(ed.[Pass 4 Deads] AS FLOAT)), 0) AS [Pass 4 Deads],
        ROUND(AVG(CAST(ed.[Pass 6 Deads] AS FLOAT)), 0) AS [Pass 6 Deads],
        ROUND(AVG(CAST(ed.[Pass 7 Deads] AS FLOAT)), 0) AS [Pass 7 Deads],
        ROUND(AVG(CAST(ed.[Pass 8 Deads] AS FLOAT)), 0) AS [Pass 8 Deads],

        -- Assistance and RSS (EXCEL stores deltas)
        ROUND(AVG(CAST(ed.[HelpsDelta] AS FLOAT)), 0) AS [Helps],
        ROUND(AVG(CAST(ed.[RSS_Assist_Delta] AS FLOAT)), 0) AS [RSS_Assist],
        ROUND(AVG(CAST(ed.[RSS_Gathered_Delta] AS FLOAT)), 0) AS [RSS_Gathered],

        -- Healed troops and related
        ROUND(AVG(CAST(ed.[Starting_HealedTroops] AS FLOAT)), 0) AS [Starting HealedTroops],
        ROUND(AVG(CAST(ed.[HealedTroopsDelta] AS FLOAT)), 0) AS [HealedTroopsDelta],
        ROUND(AVG(CAST(ed.[Starting_KillPoints] AS FLOAT)), 0) AS [Starting KillPoints],
        ROUND(AVG(CAST(ed.[KillPointsDelta] AS FLOAT)), 0) AS [KillPointsDelta],
        ROUND(AVG(CAST(ed.[RangedPoints] AS FLOAT)), 0) AS [RangedPoints],
        ROUND(AVG(CAST(ed.[RangedPointsDelta] AS FLOAT)), 0) AS [RangedPointsDelta],

        -- Gameplay summary
        ROUND(AVG(CAST(ed.[KvKPlayed] AS FLOAT)), 0) AS [KvKPlayed],
        ROUND(AVG(CAST(ed.[MostKvKKill] AS FLOAT)), 0) AS [MostKvKKill],
        ROUND(AVG(CAST(ed.[MostKvKDead] AS FLOAT)), 0) AS [MostKvKDead],
        ROUND(AVG(CAST(ed.[MostKvKHeal] AS FLOAT)), 0) AS [MostKvKHeal],
        ROUND(AVG(CAST(ed.[Acclaim] AS FLOAT)), 0) AS [Acclaim],
        ROUND(AVG(CAST(ed.[HighestAcclaim] AS FLOAT)), 0) AS [HighestAcclaim],
        ROUND(AVG(CAST(ed.[AOOJoined] AS FLOAT)), 0) AS [AOOJoined],
        ROUND(AVG(CAST(ed.[AOOWon] AS FLOAT)), 0) AS [AOOWon],
        ROUND(AVG(CAST(ed.[AOOAvgKill] AS FLOAT)), 0) AS [AOOAvgKill],
        ROUND(AVG(CAST(ed.[AOOAvgDead] AS FLOAT)), 0) AS [AOOAvgDead],
        ROUND(AVG(CAST(ed.[AOOAvgHeal] AS FLOAT)), 0) AS [AOOAvgHeal],
        CAST(NULL AS decimal(5,2)) AS [Conduct],

        -- Max / rank fields
        ROUND(AVG(CAST(ed.[Max_PreKvk_Points] AS FLOAT)), 0) AS [Max_PreKvk_Points],
        ROUND(AVG(CAST(ed.[Max_HonorPoints] AS FLOAT)), 0) AS [Max_HonorPoints],
        ROUND(AVG(CAST(ed.[PreKvk_Rank] AS FLOAT)), 0) AS [PreKvk_Rank],
        ROUND(AVG(CAST(ed.[Honor_Rank] AS FLOAT)), 0) AS [Honor_Rank],

        -- NEW: AutarchTimes
        ROUND(AVG(CAST(ed.[AutarchTimes] AS FLOAT)), 0) AS [AutarchTimes],

        -- KVK_NO
        ed.KVK_NO,

        -- Placeholder for Civilization; will compute mode in subsequent UPDATE
        CAST(NULL AS NVARCHAR(100)) AS [Civilization]
    INTO #Aggregated
    FROM #RankingGroups rg
    INNER JOIN dbo.EXCEL_FOR_DASHBOARD ed
        ON ed.KVK_NO = rg.KVK_NO
        AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
    GROUP BY rg.RankGroup, ed.KVK_NO;

    -- Optimization: Add index for the UPDATE operation
    CREATE CLUSTERED INDEX IX_Aggregated ON #Aggregated(KVK_NO, KVK_RANK);

    ----------------------------------------------------------------
    -- Step 3: Compute most common Civilization per (KVK_NO, RankGroup)
    -- Optimization: Improved tie-breaking logic
    ----------------------------------------------------------------
    UPDATE a
    SET a.Civilization = civ.Civilization
    FROM #Aggregated a
    INNER JOIN #RankingGroups rg
        ON a.KVK_NO = rg.KVK_NO
        AND a.KVK_RANK = rg.RankGroup
    CROSS APPLY (
        SELECT TOP (1) t.Civilization
        FROM (
            SELECT 
                e2.Civilization, 
                COUNT(*) AS cnt, 
                MIN(e2.Gov_ID) AS min_gov
            FROM dbo.EXCEL_FOR_DASHBOARD e2
            WHERE e2.KVK_NO = rg.KVK_NO
              AND e2.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
              AND e2.Civilization IS NOT NULL
              AND e2.Civilization <> ''''
            GROUP BY e2.Civilization
        ) t
        ORDER BY t.cnt DESC, t.min_gov ASC
    ) AS civ(Civilization);

    ----------------------------------------------------------------
    -- Step 4: Insert into DASH
    -- Optimization: Column order matches table definition for better performance
    ----------------------------------------------------------------
    INSERT INTO dbo.DASH (
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [HealedTroops],
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
        [KvKPlayed],
        [MostKvKKill], 
        [MostKvKDead], 
        [MostKvKHeal], 
        [Acclaim], 
        [HighestAcclaim],
        [AOOJoined], 
        [AOOWon], 
        [AOOAvgKill], 
        [AOOAvgDead], 
        [AOOAvgHeal],
        [Conduct],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HelpsDelta], 
        [RSS_Assist_Delta], 
        [RSS_Gathered_Delta],
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    )
    SELECT
        [RANK], 
        [KVK_RANK], 
        [Gov_ID], 
        [Governor_Name],
        [Starting Power], 
        [T4_KILLS], 
        [T5_KILLS], 
        [T4&T5_Kills],
        [Kill Target], 
        [% of Kill target], 
        [Deads], 
        [T4_Deads],
        [T5_Deads], 
        [Dead_Target], 
        [% of Dead_Target], 
        [KVK_NO],
        [Pass 4 Kills], 
        [Pass 6 Kills], 
        [Pass 7 Kills], 
        [Pass 8 Kills],
        [POWER_DELTA], 
        [DKP_Score], 
        [DKP Target], 
        [% of DKP Target],
        [Starting HealedTroops],  -- Maps to HealedTroops in DASH
        [HealedTroopsDelta], 
        [KillPointsDelta], 
        [RangedPoints], 
        [KvKPlayed],
        [MostKvKKill], 
        [MostKvKDead], 
        [MostKvKHeal], 
        [Acclaim], 
        [HighestAcclaim],
        [AOOJoined], 
        [AOOWon], 
        [AOOAvgKill], 
        [AOOAvgDead], 
        [AOOAvgHeal],
        [Conduct],
        [Starting KillPoints], 
        [Starting Deads], 
        [Starting T4&T5_KILLS],
        [Helps], 
        [RSS_Assist], 
        [RSS_Gathered],
        [Pass 4 Deads], 
        [Pass 6 Deads], 
        [Pass 7 Deads], 
        [Pass 8 Deads],
        [Starting HealedTroops],
        [Civilization],
        [KILLS_OUTSIDE_KVK], 
        [DEADS_OUTSIDE_KVK], 
        [Zeroed],
        [HealedTroopsDelta],      -- Maps to HelpsDelta in DASH
        [RSS_Assist],             -- Maps to RSS_Assist_Delta in DASH
        [RSS_Gathered],           -- Maps to RSS_Gathered_Delta in DASH
        [RangedPointsDelta],
        [Max_PreKvk_Points], 
        [Max_HonorPoints], 
        [PreKvk_Rank], 
        [Honor_Rank],
        [AutarchTimes]  -- NEW COLUMN
    FROM #Aggregated;

    ----------------------------------------------------------------
    -- Step 5: Insert the aggregated rows back into EXCEL_FOR_DASHBOARD
    -- Optimization: Batch delete using EXISTS instead of JOIN
    ----------------------------------------------------------------
    DELETE FROM dbo.EXCEL_FOR_DASHBOARD
    WHERE Gov_ID IN (''999999997'', ''999999998'', ''999999999'')
      AND EXISTS (SELECT 1 FROM dbo.DASH d WHERE d.KVK_NO = EXCEL_FOR_DASHBOARD.KVK_NO);

    -- Build dynamic column mapping
    DECLARE @cols NVARCHAR(MAX) = N'''';
    DECLARE @sels NVARCHAR(MAX) = N'''';

    ;WITH ColumnMapping (dest_col, src_expr) AS (
        SELECT * FROM (VALUES
            (N''Rank'',                 N''[RANK]''),
            (N''KVK_RANK'',             N''[KVK_RANK]''),
            (N''Gov_ID'',               N''[Gov_ID]''),
            (N''Governor_Name'',        N''[Governor_Name]''),
            (N''Starting Power'',       N''[Starting Power]''),
            (N''Power_Delta'',          N''[POWER_DELTA]''),
            (N''T4_KILLS'',             N''[T4_KILLS]''),
            (N''T5_KILLS'',             N''[T5_KILLS]''),
            (N''T4&T5_Kills'',          N''[T4&T5_Kills]''),
            (N''Kill Target'',          N''[Kill Target]''),
            (N''% of Kill Target'',     N''[% of Kill target]''),
            (N''Starting_Deads'',       N''[Starting Deads]''),
            (N''Deads_Delta'',          N''[Deads]''),  -- Map aggregate Deads to Deads_Delta
            (N''T4_Deads'',             N''[T4_Deads]''),
            (N''T5_Deads'',             N''[T5_Deads]''),
            (N''Dead_Target'',          N''[Dead_Target]''),
            (N''% of Dead Target'',     N''[% of Dead_Target]''),
            (N''DKP_SCORE'',            N''[DKP_Score]''),
            (N''DKP Target'',           N''[DKP Target]''),
            (N''% of DKP Target'',      N''[% of DKP Target]''),
            (N''Pass 4 Kills'',         N''[Pass 4 Kills]''),
            (N''Pass 6 Kills'',         N''[Pass 6 Kills]''),
            (N''Pass 7 Kills'',         N''[Pass 7 Kills]''),
            (N''Pass 8 Kills'',         N''[Pass 8 Kills]''),
            (N''Pass 4 Deads'',         N''[Pass 4 Deads]''),
            (N''Pass 6 Deads'',         N''[Pass 6 Deads]''),
            (N''Pass 7 Deads'',         N''[Pass 7 Deads]''),
            (N''Pass 8 Deads'',         N''[Pass 8 Deads]''),
            (N''KVK_NO'',               N''[KVK_NO]''),
            (N''HelpsDelta'',           N''[Helps]''),
            (N''RSS_Assist_Delta'',     N''[RSS_Assist]''),
            (N''RSS_Gathered_Delta'',   N''[RSS_Gathered]''),
            (N''Starting_HealedTroops'', N''[Starting HealedTroops]''),
            (N''HealedTroopsDelta'',    N''[HealedTroopsDelta]''),
            (N''KillPointsDelta'',      N''[KillPointsDelta]''),
            (N''RangedPoints'',         N''[RangedPoints]''),
            (N''RangedPointsDelta'',    N''[RangedPointsDelta]''),
            (N''Civilization'',         N''[Civilization]''),
            (N''KvKPlayed'',            N''[KvKPlayed]''),
            (N''MostKvKKill'',          N''[MostKvKKill]''),
            (N''MostKvKDead'',          N''[MostKvKDead]''),
            (N''MostKvKHeal'',          N''[MostKvKHeal]''),
            (N''Acclaim'',              N''[Acclaim]''),
            (N''HighestAcclaim'',       N''[HighestAcclaim]''),
            (N''AOOJoined'',            N''[AOOJoined]''),
            (N''AOOWon'',               N''[AOOWon]''),
            (N''AOOAvgKill'',           N''[AOOAvgKill]''),
            (N''AOOAvgDead'',           N''[AOOAvgDead]''),
            (N''AOOAvgHeal'',           N''[AOOAvgHeal]''),
            (N''Conduct'',              N''[Conduct]''),
            (N''Starting_KillPoints'',  N''[Starting KillPoints]''),
            (N''Starting_Deads'',       N''[Starting Deads]''),
            (N''Starting_T4&T5_KILLS'', N''[Starting T4&T5_KILLS]''),
            (N''DEADS_OUTSIDE_KVK'',    N''[DEADS_OUTSIDE_KVK]''),
            (N''KILLS_OUTSIDE_KVK'',    N''[KILLS_OUTSIDE_KVK]''),
            (N''Zeroed'',               N''[Zeroed]''),
            (N''Max_PreKvk_Points'',    N''[Max_PreKvk_Points]''),
            (N''Max_HonorPoints'',      N''[Max_HonorPoints]''),
            (N''PreKvk_Rank'',          N''[PreKvk_Rank]''),
            (N''Honor_Rank'',           N''[Honor_Rank]''),
            (N''AutarchTimes'',         N''[AutarchTimes]'')  -- NEW COLUMN MAPPING
        ) v(dest_col, src_expr)
    )
    , AvailableColumns AS (
        -- Keep a single entry per destination column (case-insensitive de-duplication)
        SELECT
            MIN(dest_col) AS dest_col,
            MIN(src_expr) AS src_expr,
            LOWER(dest_col) AS ldest
        FROM ColumnMapping
        WHERE COL_LENGTH(''dbo.EXCEL_FOR_DASHBOARD'', dest_col) IS NOT NULL
        GROUP BY LOWER(dest_col)
    )
    SELECT
        @cols = STRING_AGG(QUOTENAME(dest_col), N'', '') WITHIN GROUP (ORDER BY dest_col),
        @sels = STRING_AGG(src_expr, N'', '') WITHIN GROUP (ORDER BY dest_col)
    FROM AvailableColumns;

    -- Execute dynamic INSERT if columns are available
    IF @cols IS NOT NULL AND LEN(@cols) > 0
    BEGIN
        DECLARE @sql NVARCHAR(MAX) =
            N''INSERT INTO dbo.EXCEL_FOR_DASHBOARD ('' + @cols + N'')
              SELECT '' + @sels + N''
              FROM dbo.DASH
              WHERE Gov_ID IN (''''999999997'''', ''''999999998'''', ''''999999999'''');'';

        EXEC sp_executesql @sql;
    END

    ----------------------------------------------------------------
    -- Cleanup
    ----------------------------------------------------------------
    DROP TABLE IF EXISTS #RankingGroups;
    DROP TABLE IF EXISTS #Aggregated;

    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''DASH'';
    EXEC dbo.usp_ApplyReportGovernorNames @Report=N''EXCEL_FOR_DASHBOARD'';
    SET NOCOUNT OFF;
END';
-- dbo.sp_Rebuild_ExcelForDashboard
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_Rebuild_ExcelForDashboard]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'''';
    DECLARE @unionSql NVARCHAR(MAX) = N'''';
    DECLARE @KVK INT;
    DECLARE @MaxScan INT;
    DECLARE @TableName SYSNAME;

    -- Determine latest scan order for eligibility checks
    SELECT @MaxScan = MAX(SCANORDER) FROM dbo.KingdomScanData4;

    ----------------------------------------------------------------
    -- Build dynamic UNION of EXCEL_FOR_KVK_<KVK> tables that are eligible
    -- Eligible KVK versions are those with a MATCHMAKING_SCAN value in ProcConfig
    -- smaller than the current max scanorder.
    ----------------------------------------------------------------
    DECLARE cur CURSOR FOR
    SELECT DISTINCT KVKVersion
    FROM dbo.ProcConfig
    WHERE ConfigKey = ''MATCHMAKING_SCAN''
      AND TRY_CAST(ConfigValue AS INT) < ISNULL(@MaxScan, 0)
    ORDER BY KVKVersion DESC;

    OPEN cur;
    FETCH NEXT FROM cur INTO @KVK;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @TableName = N''EXCEL_FOR_KVK_'' + CAST(@KVK AS NVARCHAR(10));

        IF OBJECT_ID(QUOTENAME(N''dbo'') + N''.'' + QUOTENAME(@TableName), N''U'') IS NOT NULL
        BEGIN
            SET @unionSql +=
                CASE
                    WHEN LEN(ISNULL(@unionSql, N'''')) = 0
                        THEN N''''
                    ELSE N''
            UNION ALL
''
                END
                + N''
            SELECT
                CAST([Rank] AS int) AS [Rank],
                CAST([KVK_RANK] AS int) AS [KVK_RANK],
                CAST([Gov_ID] AS bigint) AS [Gov_ID],
                CAST([Governor_Name] AS nvarchar(255)) AS [Governor_Name],
                CAST([Starting Power] AS bigint) AS [Starting Power],
                CAST([Power_Delta] AS bigint) AS [Power_Delta],
                CAST([Civilization] AS nvarchar(100)) AS [Civilization],
                CAST([KvKPlayed] AS int) AS [KvKPlayed],
                CAST([MostKvKKill] AS bigint) AS [MostKvKKill],
                CAST([MostKvKDead] AS bigint) AS [MostKvKDead],
                CAST([MostKvKHeal] AS bigint) AS [MostKvKHeal],
                CAST([Acclaim] AS bigint) AS [Acclaim],
                CAST([HighestAcclaim] AS bigint) AS [HighestAcclaim],
                CAST([AOOJoined] AS bigint) AS [AOOJoined],
                CAST([AOOWon] AS int) AS [AOOWon],
                CAST([AOOAvgKill] AS bigint) AS [AOOAvgKill],
                CAST([AOOAvgDead] AS bigint) AS [AOOAvgDead],
                CAST([AOOAvgHeal] AS bigint) AS [AOOAvgHeal],
                CAST([Conduct] AS decimal(5,2)) AS [Conduct],
                CAST([Starting_T4&T5_KILLS] AS bigint) AS [Starting_T4&T5_KILLS],
                CAST([T4_KILLS] AS bigint) AS [T4_KILLS],
                CAST([T5_KILLS] AS bigint) AS [T5_KILLS],
                CAST([T4&T5_Kills] AS bigint) AS [T4&T5_Kills],
                CAST([KILLS_OUTSIDE_KVK] AS bigint) AS [KILLS_OUTSIDE_KVK],
                CAST([Kill Target] AS bigint) AS [Kill Target],
                CAST([% of Kill Target] AS decimal(9,2)) AS [% of Kill Target],
                CAST([Starting_Deads] AS bigint) AS [Starting_Deads],
                CAST([Deads_Delta] AS bigint) AS [Deads_Delta],
                CAST([DEADS_OUTSIDE_KVK] AS bigint) AS [DEADS_OUTSIDE_KVK],
                CAST([T4_Deads] AS bigint) AS [T4_Deads],
                CAST([T5_Deads] AS bigint) AS [T5_Deads],
                CAST([Dead_Target] AS bigint) AS [Dead_Target],
                CAST([% of Dead Target] AS decimal(9,2)) AS [% of Dead Target],
                CAST([Zeroed] AS bit) AS [Zeroed],
                CAST([DKP_SCORE] AS bigint) AS [DKP_SCORE],
                CAST([DKP Target] AS bigint) AS [DKP Target],
                CAST([% of DKP Target] AS decimal(9,2)) AS [% of DKP Target],
                CAST([HelpsDelta] AS bigint) AS [HelpsDelta],
                CAST([RSS_Assist_Delta] AS bigint) AS [RSS_Assist_Delta],
                CAST([RSS_Gathered_Delta] AS bigint) AS [RSS_Gathered_Delta],
                CAST([Pass 4 Kills] AS bigint) AS [Pass 4 Kills],
                CAST([Pass 6 Kills] AS bigint) AS [Pass 6 Kills],
                CAST([Pass 7 Kills] AS bigint) AS [Pass 7 Kills],
                CAST([Pass 8 Kills] AS bigint) AS [Pass 8 Kills],
                CAST([Pass 4 Deads] AS bigint) AS [Pass 4 Deads],
                CAST([Pass 6 Deads] AS bigint) AS [Pass 6 Deads],
                CAST([Pass 7 Deads] AS bigint) AS [Pass 7 Deads],
                CAST([Pass 8 Deads] AS bigint) AS [Pass 8 Deads],
                CAST([Starting_HealedTroops] AS bigint) AS [Starting_HealedTroops],
                CAST([HealedTroopsDelta] AS bigint) AS [HealedTroopsDelta],
                CAST([Starting_KillPoints] AS bigint) AS [Starting_KillPoints],
                CAST([KillPointsDelta] AS bigint) AS [KillPointsDelta],
                CAST([RangedPoints] AS bigint) AS [RangedPoints],
                CAST([RangedPointsDelta] AS bigint) AS [RangedPointsDelta],
                CAST([AutarchTimes] AS bigint) AS [AutarchTimes],
                CAST([Max_PreKvk_Points] AS bigint) AS [Max_PreKvk_Points],
                CAST([Max_HonorPoints] AS bigint) AS [Max_HonorPoints],
                CAST([PreKvk_Rank] AS bigint) AS [PreKvk_Rank],
                CAST([Honor_Rank] AS bigint) AS [Honor_Rank],
                CAST([KVK_NO] AS int) AS [KVK_NO]
            FROM dbo.'' + QUOTENAME(@TableName);
        END

        FETCH NEXT FROM cur INTO @KVK;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- If there are eligible KVK tables, build the EXCEL_FOR_DASHBOARD as a union of them
    IF LEN(ISNULL(@unionSql, '''')) > 0
    BEGIN
        SET @sql = N''
        IF OBJECT_ID(''''dbo.EXCEL_FOR_DASHBOARD'''', ''''U'''') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        SELECT TOP (50000000)
               T.*,
               T.[% of Dead Target] AS [% of Dead_Target]  -- alias for compatibility
        INTO dbo.EXCEL_FOR_DASHBOARD
        FROM (
            '' + @unionSql + ''
        ) AS T
        ORDER BY KVK_NO, [RANK];
        '';

        EXEC sp_executesql @sql;

        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''EXCEL_FOR_DASHBOARD'';
        PRINT ''Rebuilt EXCEL_FOR_DASHBOARD by unioning per-KVK tables with explicit columns.'';
    END
    ELSE
    BEGIN
        PRINT ''No eligible KVK tables found based on MATCHMAKING_SCAN and Max SCANORDER.'';
    END
END';
-- dbo.sp_Rebuild_RALLY_EXPORT
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_Rebuild_RALLY_EXPORT]
WITH EXECUTE AS CALLER
AS
BEGIN
  SET NOCOUNT ON; SET XACT_ABORT ON;

  DECLARE @Baseline date =
  ( SELECT CAST(MAX(SnapshotAt) AS date) FROM dbo.cur_RallyTotals_Base );

  BEGIN TRAN;

  DELETE FROM dbo.RALLY_EXPORT;

  ;WITH DailyAgg AS
  (
    SELECT GovernorID,
           MAX(GovernorName) AS GovernorName,
           SUM(TotalRallies) AS TotalRallies,
           SUM(RalliesLaunched) AS RalliesLaunched,
           SUM(RalliesJoined) AS RalliesJoined
    FROM dbo.cur_RallyDaily
    WHERE (@Baseline IS NULL OR AsOfDate > @Baseline)
    GROUP BY GovernorID
  ),
  Base AS
  (
    SELECT GovernorID, GovernorName, TotalRallies, RalliesLaunched, RalliesJoined
    FROM dbo.cur_RallyTotals_Base
  ),
  Final AS
  (
    SELECT
      COALESCE(d.GovernorID, b.GovernorID) AS GovernorID,
      COALESCE(d.GovernorName, b.GovernorName) AS GovernorName,
      COALESCE(b.TotalRallies, 0)    + COALESCE(d.TotalRallies, 0)    AS TotalRallies,
      COALESCE(b.RalliesLaunched, 0) + COALESCE(d.RalliesLaunched, 0) AS RalliesLaunched,
      COALESCE(b.RalliesJoined, 0)   + COALESCE(d.RalliesJoined, 0)   AS RalliesJoined
    FROM DailyAgg d
    FULL OUTER JOIN Base b ON b.GovernorID = d.GovernorID
  )
  INSERT dbo.RALLY_EXPORT (GOVENOR, RALLY_LAUNCHED, RALLY_JOINED, TOTAL_RALLIES_COMPLETED)
  SELECT
    CONCAT(RTRIM(f.GovernorName), '' ('', CONVERT(varchar(20), f.GovernorID), '')'') AS GOVENOR,
    f.RalliesLaunched,
    f.RalliesJoined,
    f.TotalRallies
  FROM Final f
  WHERE f.GovernorID <> 0;

  EXEC dbo.usp_ApplyReportGovernorNames @Report=N''RALLY_EXPORT'';
  COMMIT;
END;';
-- dbo.UPDATE_RALLY_DATA
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_RALLY_DATA]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

    DECLARE @FileExists INT;

    -- Check if file exists
    EXEC master.dbo.xp_fileexist ''C:\discord_file_downloader\downloads\rally_data.csv'', @FileExists OUTPUT;

    IF @FileExists = 1
    BEGIN
        BEGIN TRY
            -- Step 1: Load data
            TRUNCATE TABLE RallyData_Raw;

            BULK INSERT RallyData_Raw
            FROM ''C:\discord_file_downloader\downloads\rally_data.csv''
            WITH (
                FORMAT = ''CSV'',
                FIRSTROW = 2,
                FIELDTERMINATOR = '','',
                ROWTERMINATOR = ''\n'',
                TABLOCK
            );

            --PRINT ''Bulk insert completed.'';

            -- Step 2: Clean and transform date
            TRUNCATE TABLE RallyData;

            SELECT *,
                   CAST(LEFT(start_time, CHARINDEX(''@'', start_time) - 1) AS nvarchar) AS extracted_date
            INTO #TEST1
            FROM RallyData_Raw
            WHERE start_time LIKE ''%@%'';

            SELECT *,
                   LTRIM(RTRIM(extracted_date)) AS fully_trimmed_value
            INTO #TEST2
            FROM #TEST1;

            SELECT *,
                   CAST(
                        RIGHT(fully_trimmed_value, 4) + ''-'' +
                        SUBSTRING(fully_trimmed_value, 4, 2) + ''-'' +
                        LEFT(fully_trimmed_value, 2) AS nvarchar
                   ) AS reformatted_date
            INTO #TEST3
            FROM #TEST2;

            INSERT INTO RallyData
            SELECT [id], [alliance_tag], [governor_id], [governor_name], [governor_location_x], [governor_location_y],
                   [target_location_x], [target_location_y], [target_type], [target_level], [primary_commander],
                   [secondary_commander], [launched], [cancelled], [start_time], [end_time], [hit_time], [hit_time_pretty],
                   [launch_time], [governors],
                   CAST(reformatted_date AS DATE) AS Start_Date,
                   DATEPART(WEEK, TRY_CAST(reformatted_date AS DATE)) AS Start_Week
            FROM #TEST3;

            -- Step 3: Process governor and rally stats
            TRUNCATE TABLE LATEST_GOVERNORNAME;
            TRUNCATE TABLE RALLY_STARTED_TABLE;

            SELECT DISTINCT GovernorID AS GOV_ID
            INTO #GOV
            FROM KingdomScanData4;

            SELECT GovernorID, GovernorName, SCANORDER
            INTO #GOVERNORNAME_LIST
            FROM KingdomScanData4
            GROUP BY GovernorID, GovernorName, scanorder;

            WITH RankedGovernors AS (
                SELECT GovernorID, GovernorName, SCANORDER,
                       ROW_NUMBER() OVER (PARTITION BY GovernorID ORDER BY SCANORDER DESC) AS rn
                FROM #GOVERNORNAME_LIST
            )
            INSERT INTO LATEST_GOVERNORNAME (GovernorID, TRIM_NAME, GovernorName, SCANORDER)
            SELECT GovernorID,
                   RTRIM(GovernorName) AS TRIM_NAME,
                   GovernorName,
                   SCANORDER
            FROM RankedGovernors
            WHERE rn = 1 AND GovernorID <> 0;

            INSERT INTO RALLY_STARTED_TABLE (GovernorID, RALLY_STARTED)
            SELECT LG.GovernorID,
                   COUNT(RD.[id])
            FROM LATEST_GOVERNORNAME LG
            JOIN RallyData RD ON LG.GovernorID = RD.governor_ID
            WHERE RD.Launched = ''TRUE''
            GROUP BY LG.GovernorID;

            -- Step 4: Split joiners
            TRUNCATE TABLE RALLY_JOINERS;
            TRUNCATE TABLE RALLY_JOINED;

            SELECT *
            INTO #RD1
            FROM RallyData
            WHERE Cancelled = ''FALSE'';

            WITH SplitValues AS (
                SELECT ID,
                       TRIM(value) AS value,
                       ROW_NUMBER() OVER (PARTITION BY ID ORDER BY (SELECT NULL)) AS rn
                FROM #RD1
                CROSS APPLY STRING_SPLIT(governors, '';'')
            )
            INSERT INTO RALLY_JOINERS (ID, Col1, Col2, Col3, Col4, Col5, Col6, Col7, Col8,
                                       Col9, Col10, Col11, Col12, Col13, Col14, Col15, Col16)
            SELECT ID,
                   MAX(CASE WHEN rn = 1 THEN value END),
                   MAX(CASE WHEN rn = 2 THEN value END),
                   MAX(CASE WHEN rn = 3 THEN value END),
                   MAX(CASE WHEN rn = 4 THEN value END),
                   MAX(CASE WHEN rn = 5 THEN value END),
                   MAX(CASE WHEN rn = 6 THEN value END),
                   MAX(CASE WHEN rn = 7 THEN value END),
                   MAX(CASE WHEN rn = 8 THEN value END),
                   MAX(CASE WHEN rn = 9 THEN value END),
                   MAX(CASE WHEN rn = 10 THEN value END),
                   MAX(CASE WHEN rn = 11 THEN value END),
                   MAX(CASE WHEN rn = 12 THEN value END),
                   MAX(CASE WHEN rn = 13 THEN value END),
                   MAX(CASE WHEN rn = 14 THEN value END),
                   MAX(CASE WHEN rn = 15 THEN value END),
                   MAX(CASE WHEN rn = 16 THEN value END)
            FROM SplitValues
            GROUP BY ID;

            INSERT INTO RALLY_JOINED (GovernorID, TotalOccurrences)
            SELECT L.GovernorID,
                   ISNULL(SUM(CASE WHEN t.GovernorID = L.GovernorID THEN 1 ELSE 0 END), 0)
            FROM LATEST_GOVERNORNAME L
            LEFT JOIN (
                SELECT Col1 AS GovernorID FROM RALLY_JOINERS
                UNION ALL SELECT Col2 FROM RALLY_JOINERS
                UNION ALL SELECT Col3 FROM RALLY_JOINERS
                UNION ALL SELECT Col4 FROM RALLY_JOINERS
                UNION ALL SELECT Col5 FROM RALLY_JOINERS
                UNION ALL SELECT Col6 FROM RALLY_JOINERS
                UNION ALL SELECT Col7 FROM RALLY_JOINERS
                UNION ALL SELECT Col8 FROM RALLY_JOINERS
                UNION ALL SELECT Col9 FROM RALLY_JOINERS
                UNION ALL SELECT Col10 FROM RALLY_JOINERS
                UNION ALL SELECT Col11 FROM RALLY_JOINERS
                UNION ALL SELECT Col12 FROM RALLY_JOINERS
                UNION ALL SELECT Col13 FROM RALLY_JOINERS
                UNION ALL SELECT Col14 FROM RALLY_JOINERS
                UNION ALL SELECT Col15 FROM RALLY_JOINERS
            ) t ON t.GovernorID = L.GovernorID
            GROUP BY L.GovernorID;

            -- Step 5: Final summary
            TRUNCATE TABLE RALLY_EXPORT;

            INSERT INTO RALLY_EXPORT
            SELECT CONCAT(L.TRIM_NAME, '' ('', FORMAT(L.GovernorID, ''F0''), '')'') AS GOVENOR,
                   ISNULL(RST.RALLY_STARTED, 0) AS RALLY_LAUNCHED,
                   SUM(
                       CASE
                           WHEN RST.RALLY_STARTED IS NULL THEN RJ.TotalOccurrences
                           ELSE RJ.TotalOccurrences - RST.RALLY_STARTED
                       END
                   ) AS RALLY_JOINED,
                   RJ.TotalOccurrences AS TOTAL_RALLIES_COMPLETED
            FROM LATEST_GOVERNORNAME L
            LEFT JOIN RALLY_STARTED_TABLE RST ON L.GovernorID = RST.GovernorID
            LEFT JOIN RALLY_JOINED RJ ON L.GovernorID = RJ.GovernorID
            WHERE RJ.TotalOccurrences > 0
            GROUP BY L.GovernorID, L.TRIM_NAME, RST.RALLY_STARTED, RJ.TotalOccurrences;

            EXEC dbo.usp_ApplyReportGovernorNames @Report=N''RALLY_EXPORT'';
            -- Step 6: Clean up
            DROP TABLE IF EXISTS #RD1, #GOV, #GOVERNORNAME_LIST, #TEST1, #TEST2, #TEST3;

            -- Optional: Delete the CSV file
           CREATE TABLE #dummy_output (output NVARCHAR(4000));
		   
		   -- Suppress output from xp_cmdshell
			INSERT INTO #dummy_output
			EXEC xp_cmdshell ''DEL C:\discord_file_downloader\downloads\rally_data.csv'';

			-- Drop the dummy output table afterward
			DROP TABLE IF EXISTS #dummy_output;
			
			--PRINT ''Update complete and file deleted'';

			SET ANSI_WARNINGS ON;

        END TRY
        BEGIN CATCH
            PRINT ''❌ Error occurred: '' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
    BEGIN
        PRINT ''⚠️ File not found. Import skipped.'';
    END
END;';
-- dbo.usp_S11CompleteStatsReportsCore
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReportsCore
    @CompletedFileName nvarchar(260),
    @ExportPreparationID uniqueidentifier = NULL,
    @actual_param1 float = NULL,
    @actual_param2 nvarchar(100) = NULL,
    @rowsKS5 int = 0,
    @rowsKS4 int = 0,
    @StartTime datetime = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    IF @@TRANCOUNT <> 0 THROW 51961, ''Reporting requires an unowned transaction.'', 1;
    DECLARE @CompletedStage tinyint=0;
    DECLARE @PhaseBStart datetime2=SYSUTCDATETIME(), @StepStart datetime2,
        @StepEnd datetime2, @StepDuration int, @CurrentLogUsedPct decimal(5,2)=NULL;
    DECLARE @CurrentAuditPhase NVARCHAR(64) = N''update_all2_start'';
    DECLARE @UpdateAll2PhaseAudit TABLE (
        SequenceNo INT IDENTITY(1,1) NOT NULL,
        PhaseName NVARCHAR(64) NOT NULL,
        PhaseStatus NVARCHAR(32) NOT NULL,
        StartedAtUtc DATETIME2(3) NOT NULL,
        CompletedAtUtc DATETIME2(3) NULL,
        DurationMs INT NULL,
        RowsIn INT NULL,
        RowsOut INT NULL,
        DetailsJson NVARCHAR(MAX) NULL,
        ErrorType NVARCHAR(128) NULL,
        ErrorText NVARCHAR(2000) NULL
    );

    BEGIN TRY

        BEGIN TRANSACTION;
        EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        IF @ExportPreparationID IS NOT NULL
            SELECT @CompletedStage=CompletedStage, @actual_param1=KingdomRank,
                @actual_param2=KingdomSeed, @rowsKS5=RowsKS5, @rowsKS4=RowsKS4,
                @StartTime=ImportStartedUTC
            FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
            WHERE PreparationID=@ExportPreparationID;
        COMMIT;
        IF @CompletedStage=3 RETURN;
        -- One display-name list for this report batch; metrics retain original grouping.
        CREATE TABLE #P02ReportNames (
            GovernorID bigint NOT NULL PRIMARY KEY,
            GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NOT NULL
        );
        INSERT #P02ReportNames SELECT GovernorID,GovernorName FROM dbo.v_ReportGovernorNames;

        SET @StartTime=COALESCE(@StartTime,GETDATE());

        -- *** NEW: Check log space at Phase B start ***
        SET @CurrentLogUsedPct = NULL;
        DECLARE @LogReuse NVARCHAR(60) = NULL;

        BEGIN TRY
            SELECT @CurrentLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC if DMV not available
            BEGIN TRY
                CREATE TABLE #LogSpace (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpace EXEC(''DBCC SQLPERF(LOGSPACE)'');
                SELECT @CurrentLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpace 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpace;
            END TRY
            BEGIN CATCH
                SET @CurrentLogUsedPct = NULL;
            END CATCH
        END CATCH

        BEGIN TRY
            SELECT @LogReuse = log_reuse_wait_desc
            FROM sys.databases
            WHERE name = DB_NAME();
        END TRY
        BEGIN CATCH
            SET @LogReuse = NULL;
        END CATCH

        PRINT ''Phase B Start - Log Usage: '' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Reuse Wait: '' + ISNULL(@LogReuse, ''unknown'');

        -- If log usage is high (>70%), force checkpoint before continuing
        IF @CurrentLogUsedPct IS NOT NULL AND @CurrentLogUsedPct > 70.0
        BEGIN
            PRINT ''Log usage elevated ('' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                  ''%); executing CHECKPOINT before Phase B operations...'';
            CHECKPOINT;
            
            -- Log this event for monitoring
            INSERT INTO dbo.ErrorAudit (ErrorTime, ProcedureName, ErrorNumber, ErrorMessage, ErrorLine, AdditionalInfo)
            VALUES (
                GETDATE(), ''UPDATE_ALL2'', 0, 
                ''Elevated log usage detected at Phase B start'', 0,
                ''Log usage: '' + CAST(@CurrentLogUsedPct AS VARCHAR(10)) + 
                ''%, Reuse wait: '' + ISNULL(@LogReuse, ''unknown'')
            );
        END

        IF @CompletedStage=0
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        -- Step 1: CREATE_THE_AVERAGES
        SET @CurrentAuditPhase = N''update_all2_create_averages'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_THE_AVERAGES;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_THE_AVERAGES"}'');
        PRINT ''CREATE_THE_AVERAGES: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 2: Rebuild EXCEL_FOR_DASHBOARD
        SET @CurrentAuditPhase = N''update_all2_rebuild_excel_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
            DROP TABLE dbo.EXCEL_FOR_DASHBOARD;

        EXEC dbo.sp_Rebuild_ExcelForDashboard;
        
        -- ⚡ OPTIMIZATION: Update statistics on newly built table
        IF OBJECT_ID(''dbo.EXCEL_FOR_DASHBOARD'',''U'') IS NOT NULL
        BEGIN
            UPDATE STATISTICS dbo.EXCEL_FOR_DASHBOARD WITH SAMPLE 25 PERCENT;
            PRINT ''EXCEL_FOR_DASHBOARD statistics updated'';
        END
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_Rebuild_ExcelForDashboard","target":"EXCEL_FOR_DASHBOARD"}'');
        PRINT ''sp_Rebuild_ExcelForDashboard: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        -- Step 3: CREATE_DASH2
        SET @CurrentAuditPhase = N''update_all2_create_dash2'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.CREATE_DASH2;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"CREATE_DASH2"}'');
        PRINT ''CREATE_DASH2: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        ----------------------------------------------------------------
        -- Step 4a: Refresh EXCEL_FOR_KVK table FIRST (lifted from SP_Stats_for_Upload)
        ----------------------------------------------------------------
        SET @StepStart = SYSUTCDATETIME();
        
        -- Determine which KVK and Scan to use (same logic as SP_Stats_for_Upload)
        DECLARE @LatestKVK_Upload INT;
        DECLARE @MaxScan_Upload INT = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4);
        DECLARE @MatchmakingScan_Upload INT;
        DECLARE @DraftScan_Upload INT;
        DECLARE @ScanToUse_Upload INT;

        SELECT TOP 1 @LatestKVK_Upload = KVKVersion
        FROM dbo.ProcConfig
        WHERE ConfigKey = ''MATCHMAKING_SCAN''
          AND TRY_CAST(ConfigValue AS INT) <= @MaxScan_Upload
        ORDER BY KVKVersion DESC;

        IF @LatestKVK_Upload IS NOT NULL
        BEGIN
            SELECT
                @MatchmakingScan_Upload = MAX(CASE WHEN ConfigKey = ''MATCHMAKING_SCAN'' THEN TRY_CAST(ConfigValue AS INT) END),
                @DraftScan_Upload       = MAX(CASE WHEN ConfigKey = ''DRAFTSCAN''        THEN TRY_CAST(ConfigValue AS INT) END)
            FROM dbo.ProcConfig
            WHERE KVKVersion = @LatestKVK_Upload
              AND ConfigKey IN (''MATCHMAKING_SCAN'',''DRAFTSCAN'');

            -- Decide which scan to use
            SET @ScanToUse_Upload = NULL;
            IF @MatchmakingScan_Upload IS NOT NULL AND @MaxScan_Upload >= @MatchmakingScan_Upload
                SET @ScanToUse_Upload = @MatchmakingScan_Upload;
            ELSE IF @DraftScan_Upload IS NOT NULL AND @MaxScan_Upload >= @DraftScan_Upload
                SET @ScanToUse_Upload = @DraftScan_Upload;

            IF @ScanToUse_Upload IS NOT NULL
            BEGIN
                PRINT ''Step 4a: Refreshing EXCEL_FOR_KVK_'' + CAST(@LatestKVK_Upload AS VARCHAR(10)) 
                    + '' with ScanOrder='' + CAST(@ScanToUse_Upload AS VARCHAR(10)) + ''...'';
                
                -- ✅ LIFT: Call sp_ExcelOutput_ByKVK directly here
                SET @CurrentAuditPhase = N''update_all2_excel_for_kvk_refresh'';
                SET @StepStart = SYSUTCDATETIME();
                EXEC dbo.sp_ExcelOutput_ByKVK @KVK = @LatestKVK_Upload, @Scan = @ScanToUse_Upload;
                
                SET @StepEnd = SYSUTCDATETIME();
                SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
                INSERT INTO @UpdateAll2PhaseAudit
                    (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
                VALUES
                    (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
                     N''{"procedure":"sp_ExcelOutput_ByKVK","kvk":'' + CAST(@LatestKVK_Upload AS NVARCHAR(20)) +
                     N'',"scan":'' + CAST(@ScanToUse_Upload AS NVARCHAR(20)) + N''}'');
                PRINT ''sp_ExcelOutput_ByKVK: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

            END
        END

            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=1, ReportKVK=@LatestKVK_Upload, ReportScan=@ScanToUse_Upload,
                    PrefixCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=0;
                IF @@ROWCOUNT<>1 THROW 51961, ''Reporting prefix receipt changed.'', 1;
            END;
            COMMIT;
            SET @CompletedStage=1;
        END;

        IF @CompletedStage=1
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
            IF @ExportPreparationID IS NOT NULL
                SELECT @LatestKVK_Upload=ReportKVK, @ScanToUse_Upload=ReportScan
                FROM dbo.StatsImportReportContinuation WITH (UPDLOCK,HOLDLOCK)
                WHERE PreparationID=@ExportPreparationID;
            SET @CurrentAuditPhase=N''update_all2_stats_for_upload'';
            SET @StepStart=SYSUTCDATETIME();
            IF @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                EXEC dbo.SP_Stats_for_Upload;
            SET @StepEnd=SYSUTCDATETIME();
            INSERT INTO @UpdateAll2PhaseAudit
                (PhaseName,PhaseStatus,StartedAtUtc,CompletedAtUtc,DurationMs,DetailsJson)
            VALUES (@CurrentAuditPhase,
                CASE WHEN @LatestKVK_Upload IS NOT NULL AND @ScanToUse_Upload IS NOT NULL
                    THEN N''completed'' ELSE N''skipped'' END,
                @StepStart,@StepEnd,DATEDIFF(millisecond,@StepStart,@StepEnd),
                N''{"procedure":"SP_Stats_for_Upload"}'');
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=2, UploadCompletedUTC=SYSUTCDATETIME(), Version=Version+1
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=1;
                IF @@ROWCOUNT<>1 THROW 51961, ''Upload report receipt changed.'', 1;
            END;
            COMMIT;
            SET @CompletedStage=2;
        END;

        IF @CompletedStage=2
        BEGIN
            BEGIN TRANSACTION;
            EXEC dbo.usp_S11ValidateStatsReportStage @ExportPreparationID, @CompletedFileName;
        ----------------------------------------------------------------
        -- ⚡⚡⚡ OPTIMIZED INSERT INTO ALL_STATS_FOR_DASHBAORD ⚡⚡⚡
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_all_stats_dashboard'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.ALL_STATS_FOR_DASHBAORD;

        INSERT INTO dbo.ALL_STATS_FOR_DASHBAORD WITH (TABLOCK) (
            [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
            [Starting Power], [Power_Delta], [Civilization], [KvKPlayed],
            [MostKvKKill], [MostKvKDead], [MostKvKHeal],
            [Acclaim], [HighestAcclaim], [AOOJoined], [AOOWon],
            [AOOAvgKill], [AOOAvgDead], [AOOAvgHeal], [Conduct],
            [Starting T4&T5_KILLS], [T4_KILLS], [T5_KILLS], [T4&T5_Kills],
            [KILLS_OUTSIDE_KVK], [Kill Target], [% of Kill target],
            [Starting Deads], Deads_Delta, [DEADS_OUTSIDE_KVK],
            [T4_Deads], [T5_Deads], [Dead Target], [% of Dead Target], [% of Dead_Target],
            [Zeroed], [DKP_SCORE], [DKP Target], [% of DKP Target],
            HelpsDelta, RSS_Assist_Delta, RSS_Gathered_Delta,
            [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
            [Pass 4 Deads], [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads],
            [Starting HealedTroops], [HealedTroopsDelta],
            [Starting KillPoints], [KillPointsDelta],
            [RangedPoints], [RangedPointsDelta],
            [AutarchTimes],
            [Max_PreKvk_Points], [Max_HonorPoints],
            [PreKvk_Rank], [Honor_Rank], [KVK_NO]
        )
        SELECT
            ed.[Rank], 
            ed.[KVK_RANK], 
            ed.[Gov_ID],
            RTRIM(COALESCE(ed.[Governor_Name], '''')) AS [Governor_Name],
            
            -- Numeric columns with COALESCE (handles NULL efficiently)
            COALESCE(ed.[Starting Power], 0),
            COALESCE(ed.[Power_Delta], 0),
            ed.[Civilization],  -- NULL allowed
            COALESCE(ed.[KvKPlayed], 0),
            
            COALESCE(ed.[MostKvKKill], 0),
            COALESCE(ed.[MostKvKDead], 0),
            COALESCE(ed.[MostKvKHeal], 0),
            COALESCE(ed.[Acclaim], 0),
            COALESCE(ed.[HighestAcclaim], 0),
            COALESCE(ed.[AOOJoined], 0),
            COALESCE(ed.[AOOWon], 0),
            COALESCE(ed.[AOOAvgKill], 0),
            COALESCE(ed.[AOOAvgDead], 0),
            COALESCE(ed.[AOOAvgHeal], 0),
            ed.[Conduct],
            
            COALESCE(ed.[Starting_T4&T5_KILLS], 0),
            COALESCE(ed.[T4_KILLS], 0),
            COALESCE(ed.[T5_KILLS], 0),
            COALESCE(ed.[T4&T5_Kills], 0),
            COALESCE(ed.[KILLS_OUTSIDE_KVK], 0),
            COALESCE(ed.[Kill Target], 0),
            COALESCE(ed.[% of Kill Target], 0),
            
            COALESCE(ed.[Starting_Deads], 0),
            COALESCE(ed.[Deads_Delta], 0),
            COALESCE(ed.[DEADS_OUTSIDE_KVK], 0),
            COALESCE(ed.[T4_Deads], 0),
            COALESCE(ed.[T5_Deads], 0),
            COALESCE(ed.[Dead_Target], 0),
            COALESCE(ed.[% of Dead Target], 0),
            COALESCE(ed.[% of Dead Target], 0),  -- Duplicate column (fix in schema later)
            
            COALESCE(ed.[Zeroed], 0),
            COALESCE(ed.[DKP_SCORE], 0),
            COALESCE(ed.[DKP Target], 0),
            COALESCE(ed.[% of DKP Target], 0),
            
            COALESCE(ed.[HelpsDelta], 0),
            COALESCE(ed.[RSS_Assist_Delta], 0),
            COALESCE(ed.[RSS_Gathered_Delta], 0),
            
            COALESCE(ed.[Pass 4 Kills], 0),
            COALESCE(ed.[Pass 6 Kills], 0),
            COALESCE(ed.[Pass 7 Kills], 0),
            COALESCE(ed.[Pass 8 Kills], 0),
            COALESCE(ed.[Pass 4 Deads], 0),
            COALESCE(ed.[Pass 6 Deads], 0),
            COALESCE(ed.[Pass 7 Deads], 0),
            COALESCE(ed.[Pass 8 Deads], 0),
            
            COALESCE(ed.[Starting_HealedTroops], 0),
            COALESCE(ed.[HealedTroopsDelta], 0),
            COALESCE(ed.[Starting_KillPoints], 0),
            COALESCE(ed.[KillPointsDelta], 0),
            COALESCE(ed.[RangedPoints], 0),
            COALESCE(ed.[RangedPointsDelta], 0),
            COALESCE(ed.[AutarchTimes], 0),
            
            COALESCE(ed.[Max_PreKvk_Points], 0),
            COALESCE(ed.[Max_HonorPoints], 0),
            COALESCE(ed.[PreKvk_Rank], 0),
            COALESCE(ed.[Honor_Rank], 0),
            COALESCE(ed.[KVK_NO], 0)
        FROM dbo.EXCEL_FOR_DASHBOARD AS ed
        WHERE ed.Gov_ID <> 12025033
        OPTION (RECOMPILE);  -- Fresh execution plan with current statistics
        
        DECLARE @RowsInserted INT = @@ROWCOUNT;
        
        -- ⚡ OPTIMIZATION: Update statistics after bulk insert
        UPDATE STATISTICS dbo.ALL_STATS_FOR_DASHBAORD WITH FULLSCAN;
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"ALL_STATS_FOR_DASHBAORD"}'');
        PRINT ''ALL_STATS_FOR_DASHBAORD insert: '' + CAST(@RowsInserted AS VARCHAR(10)) + '' rows, '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';
        
        ----------------------------------------------------------------
        -- Continue with POWER_BY_MONTH and remaining steps
        ----------------------------------------------------------------
        SET @CurrentAuditPhase = N''update_all2_power_by_month'';
        SET @StepStart = SYSUTCDATETIME();
        
        TRUNCATE TABLE dbo.POWER_BY_MONTH;

        INSERT INTO dbo.POWER_BY_MONTH (
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS], 
            DEADS, [MONTH], HealedTroops, RangedPoints
        )
        SELECT 
            GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
            DEADS, [MONTH], HealedTroops, RangedPoints
        FROM (
            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.KingdomScanData4
            WHERE GovernorID NOT IN (0, 12025033)
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

            UNION ALL

            SELECT 
                GovernorID, RTRIM(GovernorName) AS GovernorName,
                MAX([Power]) AS [POWER], MAX(KillPoints) AS KILLPOINTS,
                MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, 
                MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints, 
                EOMONTH(ScanDate) AS [MONTH]
            FROM dbo.THE_AVERAGES
            GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)
        ) AS T
        ORDER BY GovernorID, [MONTH];
        
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"target":"POWER_BY_MONTH"}'');
        PRINT ''POWER_BY_MONTH: '' + CAST(@StepDuration AS VARCHAR(10)) + ''ms'';

        SET @CurrentAuditPhase = N''update_all2_refresh_inactive_governors'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.sp_RefreshInactiveGovernors;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"sp_RefreshInactiveGovernors"}'');

        DECLARE @MAXDATE DATETIME = (SELECT TOP 1 ScanDate FROM dbo.KingdomScanData4 ORDER BY ScanDate DESC);

        SET @CurrentAuditPhase = N''update_all2_ks_summary_insert'';
        SET @StepStart = SYSUTCDATETIME();
        INSERT INTO dbo.KS (
            KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [CH25], 
            HealedTroops, RangedPoints, [Last Update], KINGDOM_RANK, KINGDOM_SEED
        )
        SELECT
            SUM(CAST([Power] AS BIGINT)), COUNT(GovernorID), SUM([KillPoints]),
            SUM([TOTAL_KILLS]), SUM([DEADS]),
            CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT),
            SUM(ISNULL([HealedTroops], 0)), SUM(ISNULL([RangedPoints], 0)),
            @MAXDATE, @actual_param1, @actual_param2
        FROM dbo.KingdomScanData4
        WHERE ScanDate = @MAXDATE;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"KS"}'');

        SET @CurrentAuditPhase = N''update_all2_summary_proc'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.SUMMARY_PROC;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"SUMMARY_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_governor_names'';
        SET @StepStart = SYSUTCDATETIME();
        EXEC dbo.GOVERNOR_NAMES_PROC;
        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''CompletedReports'';

        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"procedure":"GOVERNOR_NAMES_PROC"}'');

        SET @CurrentAuditPhase = N''update_all2_scan_list'';
        SET @StepStart = SYSUTCDATETIME();
        TRUNCATE TABLE dbo.SCAN_LIST;

        INSERT INTO dbo.SCAN_LIST (SCANORDER, ScanDate)
        SELECT SCANORDER, ScanDate
        FROM dbo.KingdomScanData4
        GROUP BY SCANORDER, ScanDate;
        SET @RowsInserted = @@ROWCOUNT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, RowsOut, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration, @RowsInserted,
             N''{"target":"SCAN_LIST"}'');

        ----------------------------------------------------------------
        -- *** NEW: Phase B Completion - Log Management ***
        ----------------------------------------------------------------
        
        -- Force checkpoint to write dirty pages and minimize recovery time
        SET @CurrentAuditPhase = N''update_all2_checkpoint_log'';
        SET @StepStart = SYSUTCDATETIME();
        PRINT ''Executing CHECKPOINT to flush dirty pages...'';
        CHECKPOINT;
        SET @StepEnd = SYSUTCDATETIME();
        SET @StepDuration = DATEDIFF(MILLISECOND, @StepStart, @StepEnd);
        INSERT INTO @UpdateAll2PhaseAudit
            (PhaseName, PhaseStatus, StartedAtUtc, CompletedAtUtc, DurationMs, DetailsJson)
        VALUES
            (@CurrentAuditPhase, N''completed'', @StepStart, @StepEnd, @StepDuration,
             N''{"operation":"CHECKPOINT"}'');
        PRINT ''CHECKPOINT complete.'';

        -- Get final log usage
        DECLARE @FinalLogUsedPct DECIMAL(5,2) = NULL;
        BEGIN TRY
            SELECT @FinalLogUsedPct = CAST(used_log_space_in_percent AS DECIMAL(5,2))
            FROM sys.dm_db_log_space_usage;
        END TRY
        BEGIN CATCH
            -- Fallback to DBCC
            BEGIN TRY
                CREATE TABLE #LogSpaceFinal (
                    DatabaseName NVARCHAR(128),
                    LogSize DECIMAL(18,2),
                    LogSpaceUsedPercent DECIMAL(5,2),
                    Status INT
                );
                INSERT INTO #LogSpaceFinal EXEC(''DBCC SQLPERF(LOGSPACE)'');
                SELECT @FinalLogUsedPct = LogSpaceUsedPercent 
                FROM #LogSpaceFinal 
                WHERE DatabaseName = DB_NAME();
                DROP TABLE #LogSpaceFinal;
            END TRY
            BEGIN CATCH
                SET @FinalLogUsedPct = NULL;
            END CATCH
        END CATCH

        -- Insert signal record for Python bot to detect
        IF OBJECT_ID(''dbo.LogBackupTriggerQueue'', ''U'') IS NOT NULL
        BEGIN
            INSERT INTO dbo.LogBackupTriggerQueue (
                TriggerTime, 
                ProcedureName, 
                Reason, 
                LogUsedPctBefore
            )
            VALUES (
                SYSDATETIME(), 
                ''UPDATE_ALL2'', 
                ''post_heavy_operation'',
                @FinalLogUsedPct
            );
            PRINT ''Log backup trigger queued (log usage: '' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), ''unknown'') + ''%).'';
        END

        -- Attempt to trigger log backup job (non-blocking, best effort)
        DECLARE @LogBackupTriggered BIT = 0;
        PRINT ''Log backup trigger queued for Python processing.'';

        DECLARE @EndTime DATETIME = GETDATE();
        DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);
        DECLARE @PhaseBDuration INT = DATEDIFF(MILLISECOND, @PhaseBStart, SYSUTCDATETIME());

        PRINT ''========================================'';
        PRINT ''Phase B Total: '' + CAST(@PhaseBDuration AS VARCHAR(10)) + ''ms'';
        PRINT ''Log Usage: Initial='' + ISNULL(CAST(@CurrentLogUsedPct AS VARCHAR(10)), ''unknown'') + 
              ''%, Final='' + ISNULL(CAST(@FinalLogUsedPct AS VARCHAR(10)), ''unknown'') + ''%'';
        PRINT ''Log Backup Triggered: '' + CASE WHEN @LogBackupTriggered = 1 THEN ''Yes'' ELSE ''No (queued for Python)'' END;
        PRINT ''========================================'';

        DECLARE @S11CompletionCounters TABLE (LastRunCounter int NOT NULL);
        INSERT INTO dbo.SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
        OUTPUT inserted.LastRunCounter INTO @S11CompletionCounters (LastRunCounter)
        VALUES (
            ''UPDATE_ALL2'', ''Complete'', @EndTime,
            ISNULL((SELECT MAX(LastRunCounter) FROM dbo.SP_TaskStatus WITH (UPDLOCK,HOLDLOCK) WHERE TaskName=''UPDATE_ALL2''), 0) + 1,
            @DurationSeconds
        );

        IF @ExportPreparationID IS NOT NULL
        BEGIN
            UPDATE dbo.StatsImportExecution SET State=''completed'',
                LastRunCounter=(SELECT LastRunCounter FROM @S11CompletionCounters),
                UpdatedUTC=SYSUTCDATETIME(), Version=Version+1
            WHERE PreparationID=@ExportPreparationID AND CompletedFileName=@CompletedFileName AND State IN (''import_committed'',''partial'') AND Resolution IS NULL;
            IF @@ROWCOUNT <> 1 THROW 51960, ''Missing exact Phase B execution receipt.'', 1;
        END;
            IF @ExportPreparationID IS NOT NULL
            BEGIN
                UPDATE dbo.StatsImportReportContinuation
                SET CompletedStage=3, SummaryCompletedUTC=SYSUTCDATETIME(), Version=Version+1,
                    RecoveryState=CASE WHEN RecoveryActionID IS NOT NULL THEN ''completed'' END
                WHERE PreparationID=@ExportPreparationID AND CompletedStage=2;
                IF @@ROWCOUNT<>1 THROW 51961, ''Summary receipt changed.'', 1;
            END;
            INSERT INTO dbo.Update_ALL_Complete (CompletionTime) VALUES (GETDATE());
            COMMIT;
        END;

        SELECT
            PhaseName,
            PhaseStatus,
            StartedAtUtc,
            CompletedAtUtc,
            DurationMs,
            RowsIn,
            RowsOut,
            DetailsJson,
            ErrorType,
            ErrorText
        FROM @UpdateAll2PhaseAudit
        ORDER BY SequenceNo;

        SELECT 
            @rowsKS5 AS RowsInsertedKS5,
            @rowsKS4 AS RowsInsertedKS4,
            @DurationSeconds AS DurationSeconds,
            @PhaseBDuration AS PhaseBDurationMS,
            @CurrentLogUsedPct AS LogUsedPctBefore,
            @FinalLogUsedPct AS LogUsedPctAfter,
            @LogBackupTriggered AS LogBackupTriggered,
            ''SUCCESS'' AS Status;

    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;';
-- dbo.UPDATE_ALL
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260)
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    -- Phase 2 adds filtered uniqueness indexes to the canonical scan tables.
    -- SQL Server requires ANSI_WARNINGS ON for every write touching them.
    SET ANSI_WARNINGS ON;

    IF @@TRANCOUNT <> 0
        THROW 51828, ''UPDATE_ALL refuses caller-owned transactions; execute the public entry point with no active transaction.'', 1;

    BEGIN TRY
        DECLARE @ImportFileDigest BINARY(32);
        DECLARE @ImportClaimedPath NVARCHAR(4000);
        DECLARE @ImportArchivePath NVARCHAR(4000);
        DECLARE @ImportError NVARCHAR(2000);

        EXEC dbo.CLAIM_KS4_IMPORT_FILE
            @CompletedFileName = @CompletedFileName,
            @FileDigest = @ImportFileDigest OUTPUT,
            @ClaimedPath = @ImportClaimedPath OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT;

        BEGIN TRANSACTION;

        DECLARE @ImportLockResult INT;
        DECLARE @ImportReturnCode INT;
        DECLARE @AllocatedScanOrder INT;
        DECLARE @StagedRows INT;
        DECLARE @RowsKS5 INT;
        DECLARE @RowsKS4 INT;
        DECLARE @ArchiveReturnCode INT;

        EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK
            @LockTimeout = 60000,
            @LockResult = @ImportLockResult OUTPUT;

        IF @ImportLockResult < 0
            THROW 51820, ''UPDATE_ALL could not acquire the KingdomScanData4 import mutex within 60000 ms; import was not started.'', 1;

		DECLARE @actual_param1 FLOAT = ISNULL(@param1, (SELECT TOP 1 KINGDOM_RANK FROM KS));
		DECLARE @actual_param2 NVARCHAR(100) = ISNULL(@param2, (SELECT TOP 1 KINGDOM_SEED FROM KS));
		DECLARE @StartTime DATETIME = GETDATE();

		

        DECLARE 
            @MATHCHMAKING_SCAN INT = 148,
            @MAXSCAN INT = (SELECT MAX(SCANORDER) FROM KingdomScanData4),
            @PRE_PASS_4_SCAN INT = 156,
            @KVK_END_SCAN INT = 171,
            @PASS4END INT = 161,
            @PASS6END INT = 167,
            @PASS7END INT = 170,
            @LASTKVKEND INT = 146,
            @CURRENTKVK3 INT = 11;
            --@KINGDOMRANK FLOAT = 1099,
            --@KINGDOMSEED NVARCHAR(20) = ''C Seed'';
       

        -- Step 1: Refresh latest data
        EXEC UPDATE_RALLY_DATA;
        EXEC @ImportReturnCode = dbo.IMPORT_STAGING_PROC_CORE
            @CompletedFileName = @CompletedFileName,
            @ImportFileDigest = @ImportFileDigest OUTPUT,
            @ArchivePath = @ImportArchivePath OUTPUT,
            @ImportError = @ImportError OUTPUT;

        IF @ImportReturnCode <> 0
        BEGIN
            SET @ImportError = COALESCE(
                @ImportError,
                N''UPDATE_ALL stopped because IMPORT_STAGING_PROC failed without returning error detail.''
            );
            THROW 51821, @ImportError, 1;
        END;

        SELECT
            @AllocatedScanOrder = MIN(SCANORDER),
            @StagedRows = COUNT(*)
        FROM dbo.IMPORT_STAGING;

        IF @AllocatedScanOrder IS NULL
           OR @AllocatedScanOrder <> (SELECT MAX(SCANORDER) FROM dbo.IMPORT_STAGING)
           OR @StagedRows <> (SELECT COUNT(DISTINCT [Governor ID]) FROM dbo.IMPORT_STAGING)
            THROW 51822, ''UPDATE_ALL rejected empty, mixed-scan, or duplicate-governor canonical staging.'', 1;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.KingdomScanData5
            WHERE SCANORDER = @AllocatedScanOrder
        )
            THROW 51823, ''UPDATE_ALL refused to reuse an existing KingdomScanData5 SCANORDER.'', 1;

        -- Step 2: Insert into KingdomScanData5
        INSERT INTO KingdomScanData5 (PowerRank, GovernorName, GovernorID, Alliance, Power, KillPoints, Deads,
                                      T1_Kills, T2_Kills, T3_Kills, T4_Kills, T5_Kills, [T4&T5_KILLS], TOTAL_KILLS,
                                      Rss_Gathered, RSSASSISTANCE, Helps, ScanDate, SCANORDER, [Troops Power], 
                                      [City Hall], [Tech Power], [Building Power], [Commander Power])
        SELECT ROW_NUMBER() OVER (ORDER BY [Power] DESC),
               RTRIM([Name]), [Governor ID], [Alliance], [Power], [Total Kill Points], [Dead Troops],
               [T1-Kills], [T2-Kills], [T3-Kills], [T4-Kills], [T5-Kills], [Kills (T4+)], [KILLS],
               [RSS Gathered], [RSS Assistance], [Alliance Helps], [ScanDate], [SCANORDER],
               [Troops Power], [City Hall], [Tech Power], [Building Power], [Commander Power]
        FROM IMPORT_STAGING;

        SET @RowsKS5 = @@ROWCOUNT;

        IF @RowsKS5 <> @StagedRows
           OR EXISTS
              (
                  SELECT 1
                  FROM dbo.KingdomScanData5
                  WHERE SCANORDER = @AllocatedScanOrder
                  GROUP BY SCANORDER, GovernorID
                  HAVING COUNT_BIG(*) > 1
              )
            THROW 51824, ''UPDATE_ALL KingdomScanData5 row-count or duplicate-key validation failed.'', 1;

     
		-- Step 3: Copy to KingdomScanData4 only if SCANORDER is greater
		IF (
			SELECT MAX(SCANORDER) FROM KingdomScanData5
		) > (
			SELECT ISNULL(MAX(SCANORDER), 0) FROM KingdomScanData4
		)
		BEGIN
            IF EXISTS
            (
                SELECT 1
                FROM dbo.KingdomScanData4
                WHERE SCANORDER = @AllocatedScanOrder
            )
                THROW 51825, ''UPDATE_ALL refused to reuse an existing KingdomScanData4 SCANORDER.'', 1;

			INSERT INTO KingdomScanData4
			SELECT *
			FROM KingdomScanData5 
			WHERE SCANORDER = @AllocatedScanOrder;

            SET @RowsKS4 = @@ROWCOUNT;

            IF @RowsKS4 <> @RowsKS5
               OR EXISTS
                  (
                      SELECT 1
                      FROM dbo.KingdomScanData4
                      WHERE SCANORDER = @AllocatedScanOrder
                      GROUP BY SCANORDER, GovernorID
                      HAVING COUNT_BIG(*) > 1
                  )
                THROW 51826, ''UPDATE_ALL KingdomScanData4 row-count or duplicate-key validation failed.'', 1;
		END

		

        -- Step 4: Truncate staging
        TRUNCATE TABLE IMPORT_STAGING;

		-- Step 4a: Creat Target Table--
		EXEC dbo.TARGETS;
		--EXEC dbo.TARGETS @InputScanOrder = @MATHCHMAKING_SCAN;

        -- Step 5: Create delta tables
        EXEC CREATE_DELTA_TABLES;

		-- Drop final staging table if it exists
		TRUNCATE TABLE STAGING_STATS;

		-----------------------------------------------
-- 1. Consolidated Deads Delta
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN DeadsDelta ELSE 0 END) AS P4DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN DeadsDelta ELSE 0 END) AS P6DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN DeadsDelta ELSE 0 END) AS P7DeadsDelta,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN DeadsDelta ELSE 0 END) AS P8DeadsDelta
INTO #Deads
FROM dbo.DeadsDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 2. Consolidated Kills Delta (T4&T5)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
    SUM(CASE WHEN DeltaOrder > @LASTKVKEND AND DeltaOrder <= @PRE_PASS_4_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
    SUM(CASE WHEN DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @PASS4END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
    SUM(CASE WHEN DeltaOrder > @PASS4END AND DeltaOrder <= @PASS6END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
    SUM(CASE WHEN DeltaOrder > @PASS6END AND DeltaOrder <= @PASS7END THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
    SUM(CASE WHEN DeltaOrder > @PASS7END AND DeltaOrder <= @KVK_END_SCAN THEN [T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
INTO #Kills
FROM dbo.T4T5KillDelta
WHERE DeltaOrder > @LASTKVKEND AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 3. Consolidated T4/T5 Kills
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(T4KILLSDelta, 0)) AS T4KillsDelta
INTO #KillsT4
FROM dbo.T4KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(T5KILLSDelta, 0)) AS T5KillsDelta
INTO #KillsT5
FROM dbo.T5KillDelta
WHERE DeltaOrder > @PRE_PASS_4_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 4. Other Delta Metrics (RSS, Helps, Power)
-----------------------------------------------
SELECT 
    GovernorID,
    SUM(COALESCE(HelpsDelta, 0)) AS HelpsDelta
INTO #Helps
FROM dbo.HelpsDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSASSISTDelta, 0)) AS RSSAssistDelta
INTO #RSSAssist
FROM dbo.RSSASSISTDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(RSSGatheredDelta, 0)) AS RSSGatheredDelta
INTO #RSSGathered
FROM dbo.RSSGatheredDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

SELECT 
    GovernorID,
    SUM(COALESCE(Power_Delta, 0)) AS PowerDelta
INTO #Power
FROM dbo.PowerDelta
WHERE DeltaOrder > @MATHCHMAKING_SCAN AND DeltaOrder <= @KVK_END_SCAN
GROUP BY GovernorID;

-----------------------------------------------
-- 5. Latest Snapshot of Governors
-----------------------------------------------
SELECT 
    GovernorID,
    GovernorName,
    PowerRank,
    [Power]
INTO #Snapshot
FROM KingdomScanData4
WHERE SCANORDER = @MATHCHMAKING_SCAN;

-----------------------------------------------
-- 6. Final Join to Staging Table
-----------------------------------------------
INSERT INTO STAGING_STATS
(
    GovernorID,
    PowerRank,
    [Power],
    Power_Delta,
    GovernorName,
    T4KillsDelta,
    T5KillsDelta,
    [T4&T5_KILLSDelta],
    KILLS_OUTSIDE_KVK,
    [P4T4&T5_KILLSDelta],
    [P6T4&T5_KillsDelta],
    [P7T4&T5_KillsDelta],
    [P8T4&T5_KillsDelta],
    DeadsDelta,
    DEADS_OUTSIDE_KVK,
    P4DeadsDelta,
    P6DeadsDelta,
    P7DeadsDelta,
    P8DeadsDelta,
    HelpsDelta,
    RSSASSISTDelta,
    RSSGatheredDelta
)
SELECT 
    s.GovernorID,
    s.PowerRank,
    s.[Power],
    p.PowerDelta,
    s.GovernorName,
    kt4.T4KillsDelta,
    kt5.T5KillsDelta,
    k.T4T5KillsDelta AS [T4&T5_KILLSDelta],
    k.KillsOutsideKVK AS [KILLS_OUTSIDE_KVK],
    k.P4Kills AS [P4T4&T5_KILLSDelta],
	k.P6Kills AS [P6T4&T5_KillsDelta],
	k.P7Kills AS [P7T4&T5_KillsDelta], 
	k.P8Kills AS [P8T4&T5_KillsDelta],
    d.DeadsDelta,
    d.DeadsDeltaOutKVK AS [DEADS_OUTSIDE_KVK],
    d.P4DeadsDelta,
	d.P6DeadsDelta,
	d.P7DeadsDelta,
	d.P8DeadsDelta,
    h.HelpsDelta,
    ra.RSSAssistDelta,
    rg.RSSGatheredDelta
FROM #Snapshot s
LEFT JOIN #Power p ON p.GovernorID = s.GovernorID
LEFT JOIN #KillsT4 kt4 ON kt4.GovernorID = s.GovernorID
LEFT JOIN #KillsT5 kt5 ON kt5.GovernorID = s.GovernorID
LEFT JOIN #Kills k ON k.GovernorID = s.GovernorID
LEFT JOIN #Deads d ON d.GovernorID = s.GovernorID
LEFT JOIN #Helps h ON h.GovernorID = s.GovernorID
LEFT JOIN #RSSAssist ra ON ra.GovernorID = s.GovernorID
LEFT JOIN #RSSGathered rg ON rg.GovernorID = s.GovernorID
WHERE s.GovernorID IS NOT NULL
ORDER BY s.PowerRank;

-----------------------------------------------
-- 7. Cleanup
-----------------------------------------------
DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot;

SELECT  S1.[GovernorID],
		CASE WHEN z.GovernorID = s1.GovernorID
		THEN ROUND ((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) *8) ,0)
		ELSE ROUND ((S1.[T4&T5_KILLSDelta]*3 + S1.[DeadsDelta] *8) ,0)
		END AS [DKP_Score]
		INTO #DKP
		FROM [dbo].[STAGING_STATS] AS S1
	 LEFT JOIN ZEROED AS Z ON z.GovernorID=S1.GovernorID AND ScanOrder = @MATHCHMAKING_SCAN 

SELECT GovernorID, MAX(T4_Deads) as [T4 Deads], MAX (T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
INTO #HD1
FROM HoH_Deads 
GROUP BY GovernorID

  DROP TABLE EXCEL_FOR_CURRENT_KVK

SELECT	TOP (5000)
		S.[PowerRank] AS [Rank],
		ROW_NUMBER() OVER (ORDER BY D.[DKP_Score] DESC) AS [KVK_RANK]
		,S.[GovernorID] AS Gov_ID
		,S.[GovernorName] AS [Governor_Name]
		,S.[Power] AS [Starting Power]
		,S.Power_Delta
		,s.T4KillsDelta AS [T4_KILLS]
		,s.T5KillsDelta AS [T5_KILLS]
		,S.[T4&T5_KILLSDelta] AS [T4&T5_Kills]
		,S.KILLS_OUTSIDE_KVK
		,t.[Kill Target] AS [Kill Target]
		,CASE WHEN t.[Kill Target]  = 0
				THEN 0
				ELSE ROUND(s.[T4&T5_KILLSDelta]/t.[Kill Target]  * 100, 2) 
				END AS [% of Kill target]
		,s.[DeadsDelta] AS Deads
		,s.DEADS_OUTSIDE_KVK
		,COALESCE(HD.[T4 Deads],0) AS T4_Deads
		,COALESCE(HD.[T5 Deads],0) AS T5_Deads
		,t.[Dead Target] AS [Dead Target]
		
		,CASE WHEN t.[Dead Target] = 0
			THEN 0
			WHEN z.GovernorID = s.GovernorID
			THEN ROUND((s.DeadsDelta * 0.1)/t.[Dead Target] *100, 2) 
			ELSE ROUND(s.DeadsDelta/t.[Dead Target] *100, 2) 
			END AS [% of Dead Target]
			,z.Zeroed
		,D.[DKP_SCORE]
		,t.[DKP TARGET] AS [DKP Target]
		,CASE WHEN t.[Kill Target] = 0
				THEN 0
				WHEN z.GovernorID = s.GovernorID
				THEN ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				ELSE ROUND( (D.[DKP_SCORE] / (t.[Kill Target]  * 3 + (t.[Dead Target] * 8)) *100) ,2)
				END AS [% of DKP Target]
		,S.[HelpsDelta] AS Helps
		,S.[RSSASSISTDelta] AS RSS_Assist
		,S.[RSSGatheredDelta] AS RSS_Gathered
		,S.[P4T4&T5_KillsDelta] AS [Pass 4 Kills]
	  ,[P6T4&T5_KillsDelta] AS [Pass 6 Kills]
	  ,[P7T4&T5_KillsDelta] AS [Pass 7 Kills]
	  ,[P8T4&T5_KillsDelta] AS [Pass 8 Kills]
	  ,P4DeadsDelta AS [Pass 4 Deads]
	  ,P6DeadsDelta AS [Pass 6 Deads]
	  ,P7DeadsDelta AS [Pass 7 Deads]
	  ,P8DeadsDelta AS [Pass 8 Deads]
	  ,@CURRENTKVK3 AS [KVK_NO]
	  INTO EXCEL_FOR_CURRENT_KVK
	  --INTO EXCEL_FOR_JAN25_KVK
  FROM [dbo].[STAGING_STATS] AS S
  LEFT JOIN #HD1 AS HD on S.GovernorID=HD.GovernorID
  JOIN EXCEL_OUTPUT_KVK_TARGETS_MAR25 AS T ON T.gov_id=S.Governorid
  LEFT JOIN #DKP AS D on D.GovernorID=S.Governorid
  LEFT JOIN ZEROED AS Z ON z.GovernorID=S.GovernorID AND Z.ScanOrder = @MATHCHMAKING_SCAN 
  ORDER BY PowerRank ASC

        -- One display-name list for this report batch; metrics retain original grouping.
        CREATE TABLE #P02ReportNames (
            GovernorID bigint NOT NULL PRIMARY KEY,
            GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NOT NULL
        );
        INSERT #P02ReportNames SELECT GovernorID,GovernorName FROM dbo.v_ReportGovernorNames;

EXEC CREATE_THE_AVERAGES 

DROP TABLE #DKP, #HD1, EXCEL_FOR_DASHBOARD

SELECT TOP (5000000)
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill target],
    [Deads] AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead Target] AS [Dead_Target],
    [% of Dead Target],
    [Zeroed],
    [DKP_SCORE],
    [DKP Target],
    [% of DKP Target],
    [Helps] AS [HelpsDelta],
    [RSS_Assist] AS [RSS_Assist_Delta],
    [RSS_Gathered] AS [RSS_Gathered_Delta],
    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],
    [KVK_NO]
INTO EXCEL_FOR_DASHBOARD
FROM

( SELECT * 
  FROM EXCEL_FOR_CURRENT_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_JAN25_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_SEPT24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_MAY24_KVK
  UNION
  SELECT * 
  FROM  EXCEL_FOR_FEB24_KVK
  UNION
  SELECT * 
  FROM EXCEL_FOR_OCT23_KVK
  UNION 
  SELECT * 
  FROM EXCEL_FOR_JUL23_KVK) AS T
ORDER BY KVK_NO, [RANK]

EXEC CREATE_DASH

---- OUTPUT NUMBER 1 = KVK STATS ----
DECLARE
@MAXDATE AS datetime2(0) = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE STATS_FOR_UPLOAD

TRUNCATE TABLE STATS_FOR_UPLOAD

INSERT INTO STATS_FOR_UPLOAD
(
[Rank],
[KVK_RANK],
[Gov_ID],
[Governor_Name],
[Starting Power],
[Power_Delta],
[T4_KILLS],
[T5_KILLS],
[T4&T5_Kills],
[KILLS_OUTSIDE_KVK],
[Kill Target],
[% of Kill Target],
[Deads_Delta],
[DEADS_OUTSIDE_KVK],
[T4_Deads],
[T5_Deads],
[Dead_Target],
[% of Dead Target],
[Zeroed],
[DKP_SCORE],
[DKP Target],
[% of DKP Target],
[HelpsDelta],
[RSS_Assist_Delta],
[RSS_Gathered_Delta],
[Pass 4 Kills],
[Pass 6 Kills],
[Pass 7 Kills],
[Pass 8 Kills],
[Pass 4 Deads],
[Pass 6 Deads],
[Pass 7 Deads],
[Pass 8 Deads],
[KVK_NO],
[LAST_REFRESH]
)
SELECT 
[Rank], KVK_RANK, Gov_ID AS [Governor ID], RTRIM(Governor_Name) AS [Governor_Name], [Starting Power] AS [Power], ISNULL(Power_Delta, 0) AS [Power Delta] , ISNULL(T4_KILLS, 0) T4_Kills, ISNULL(T5_KILLS, 0) T5_Kills,
ISNULL([T4&T5_Kills],0) [T4&T5_Kills], KILLS_OUTSIDE_KVK AS [OFF_SEASON_KILLS], [Kill Target], ISNULL([% of Kill target], 0) [% of Kill target], ISNULL(Deads, 0) Deads, DEADS_OUTSIDE_KVK AS [OFF_SEASON_DEADS],
T4_Deads, T5_Deads, [Dead Target], ISNULL([% of Dead Target], 0) [% of Dead Target], ISNULL(Zeroed, 0) Zeroed, ISNULL([DKP_Score], 0) [DKP_SCORE], [DKP Target],
ISNULL([% of DKP Target], 0) [% of DKP Target], ISNULL(HELPS, 0) Helps, ISNULL(RSS_Assist, 0) RSS_Assist, ISNULL(RSS_Gathered, 0 ) RSS_Gathered, 
ISNULL([Pass 4 Kills], 0) [Pass 4 Kills], ISNULL([Pass 6 Kills], 0) [Pass 6 Kills], ISNULL([Pass 7 Kills], 0) [Pass7 Kills], ISNULL([Pass 8 Kills], 0) [Pass 8 Kills],
ISNULL([Pass 4 Deads], 0) [Pass 4 Deads], ISNULL([Pass 6 Deads], 0) [Pass 6 Deads], ISNULL([Pass 7 Deads], 0) [Pass 7 Deads], ISNULL([Pass 8 Deads], 0) [Pass 8 Deads], KVK_NO, @MAXDATE AS LAST_REFRESH
--INTO STATS_FOR_UPLOAD
FROM EXCEL_FOR_CURRENT_KVK 
WHERE Gov_ID <> 12025033
ORDER BY [RANK] ASC;

--SELECT * FROM STATS_FOR_UPLOAD

---- OUTPUT NUMBER 2 = ALL STATS FOR DASHBOARD ----

TRUNCATE TABLE ALL_STATS_FOR_DASHBAORD

INSERT INTO ALL_STATS_FOR_DASHBAORD
(
      [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
      [Starting Power], [Power_Delta], [T4_Kills], [T5_Kills],
      [T4&T5_Kills], [Kill Target], [% of Kill target],
      [Deads_Delta], [T4_Deads], [T5_Deads], [Dead Target],
      [% of Dead Target], [Zeroed], [DKP_SCORE], [DKP Target],
      [% of DKP Target], [HelpsDelta], [RSS_Assist_Delta],
      [RSS_Gathered_Delta], [Pass 4 Kills], [Pass 6 Kills],
      [Pass 7 Kills], [Pass 8 Kills], [Pass 4 Deads],
      [Pass 6 Deads], [Pass 7 Deads], [Pass 8 Deads], [KVK_NO]
)
SELECT
      ed.[Rank],
      ed.[KVK_RANK],
      ed.[Gov_ID],
      ISNULL(RTRIM(ed.[Governor_Name]), '''') AS [Governor_Name],
      ed.[Starting Power],
      ISNULL(ed.[Power_Delta], 0) AS [Power_Delta],
      ISNULL(ed.[T4_KILLS], 0) AS [T4_Kills],
      ISNULL(ed.[T5_KILLS], 0) AS [T5_Kills],
      ISNULL(ed.[T4&T5_Kills], 0) AS [T4&T5_Kills],
      ISNULL(ed.[Kill Target], 0) AS [Kill Target],
      ISNULL(ed.[% of Kill Target], 0) AS [% of Kill target],
      ISNULL(ed.[Deads_Delta], 0) AS [Deads_Delta],
      ISNULL(ed.[T4_Deads], 0) AS [T4_Deads],
      ISNULL(ed.[T5_Deads], 0) AS [T5_Deads],
      ISNULL(ed.[Dead_Target], 0) AS [Dead Target],
      ISNULL(ed.[% of Dead Target], 0) AS [% of Dead Target],
      ISNULL(ed.[Zeroed], 0) AS [Zeroed],
      ISNULL(ed.[DKP_SCORE], 0) AS [DKP_SCORE],
      ISNULL(ed.[DKP Target], 0) AS [DKP Target],
      ISNULL(ed.[% of DKP Target], 0) AS [% of DKP Target],
      ISNULL(ed.[HelpsDelta], 0) AS [HelpsDelta],
      ISNULL(ed.[RSS_Assist_Delta], 0) AS [RSS_Assist_Delta],
      ISNULL(ed.[RSS_Gathered_Delta], 0) AS [RSS_Gathered_Delta],
      ISNULL(ed.[Pass 4 Kills], 0) AS [Pass 4 Kills],
      ISNULL(ed.[Pass 6 Kills], 0) AS [Pass 6 Kills],
      ISNULL(ed.[Pass 7 Kills], 0) AS [Pass 7 Kills],
      ISNULL(ed.[Pass 8 Kills], 0) AS [Pass 8 Kills],
      ISNULL(ed.[Pass 4 Deads], 0) AS [Pass 4 Deads],
      ISNULL(ed.[Pass 6 Deads], 0) AS [Pass 6 Deads],
      ISNULL(ed.[Pass 7 Deads], 0) AS [Pass 7 Deads],
      ISNULL(ed.[Pass 8 Deads], 0) AS [Pass 8 Deads],
      ed.[KVK_NO]
FROM [dbo].[EXCEL_FOR_DASHBOARD] AS ed
WHERE ed.Gov_ID <> 12025033

  --SELECT * FROM ALL_STATS_FOR_DASHBAORD

 ---- OUTPUT NUMBER 3 = POWER BY MONTH ---- 
 TRUNCATE TABLE POWER_BY_MONTH
 
 INSERT INTO POWER_BY_MONTH
 (
 GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
 DEADS, [MONTH], HealedTroops, RangedPoints
 )
 SELECT TOP (5000000)
 GovernorID, GovernorName, [POWER], KILLPOINTS, [T4&T5KILLS],
 DEADS, [MONTH], HealedTroops, RangedPoints

 FROM (

SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName] ,MAX([Power]) AS ''POWER'', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH], MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints
FROM  KingdomScanData4
WHERE GovernorID NOT IN (0, 12025033)
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)

UNION

SELECT GovernorID, RTRIM(GovernorName) AS [GovernorName], MAX([Power]) AS ''POWER'', MAX(KillPoints) AS KILLPOINTS, MAX([T4&T5_KILLS]) AS [T4&T5KILLS], MAX(Deads) AS DEADS, EOMONTH(ScanDate) AS [MONTH], MAX(HealedTroops) AS HealedTroops, MAX(RangedPoints) AS RangedPoints
FROM THE_AVERAGES
GROUP BY GovernorID, GovernorName, EOMONTH(ScanDate)) AS T
ORDER BY GovernorID, [MONTH];

--SELECT * FROM POWER_BY_MONTH

EXEC sp_RefreshInactiveGovernors

TRUNCATE TABLE [KS]

--DECLARE
--@MAXDATE AS DATETIME = (SELECT MAX(ScanDate) FROM KingdomScanData4)

--DROP TABLE IF EXISTS [KS]

INSERT INTO [KS]
(
KINGDOM_POWER, Governors, KP, [KILL], [DEAD], [Last Update],
KINGDOM_RANK, KINGDOM_SEED, CH25, HealedTroops, RangedPoints
)
SELECT SUM(CAST([Power] AS BIGINT)) AS KINGDOM_POWER,
COUNT(GovernorID) AS Governors,
SUM([KillPoints]) AS KP,
SUM([TOTAL_KILLS]) as [KILL],
SUM([DEADS]) AS [DEAD],
@MAXDATE AS [Last Update],
--''1554'' AS KINGDOM_RANK,
@actual_param1 AS KINGDOM_RANK,
--''C'' AS KINGDOM_SEED
@actual_param2 AS KINGDOM_SEED,
CAST(SUM(CASE WHEN [City Hall] = 25 THEN 1 ELSE 0 END) AS INT) AS CH25,
SUM(ISNULL([HealedTroops], 0)) AS HealedTroops,
SUM(ISNULL([RangedPoints], 0)) AS RangedPoints
--INTO [KS]
FROM KingdomScanData4
WHERE ScanDate = @MAXDATE

--SELECT * FROM [KS]

EXEC SUMMARY_PROC

EXEC GOVERNOR_NAMES_PROC
        EXEC dbo.usp_ApplyReportGovernorNames @Report=N''CompletedReports'';


DECLARE @EndTime DATETIME = GETDATE();
DECLARE @DurationSeconds INT = DATEDIFF(SECOND, @StartTime, @EndTime);

INSERT INTO SP_TaskStatus (TaskName, Status, LastRunTime, LastRunCounter, DurationSeconds)
VALUES (
    ''UPDATE_ALL'',
    ''Complete'',
    @EndTime,
    ISNULL((SELECT MAX(LastRunCounter) FROM SP_TaskStatus WHERE TaskName = ''UPDATE_ALL''), 0) + 1,
    @DurationSeconds
);

SET ANSI_WARNINGS ON;

        COMMIT;

        EXEC @ArchiveReturnCode = dbo.ARCHIVE_IMPORT_STAGING_FILE
            @CompletedFileName = @CompletedFileName;

        IF @ArchiveReturnCode <> 0
            THROW 51827, ''UPDATE_ALL committed its database work but the immutable-file archive handoff did not complete.'', 1;

		INSERT INTO Update_ALL_Complete (CompletionTime)
		VALUES (GETDATE());


    END TRY
    BEGIN CATCH
        DECLARE @OuterPersistedError nvarchar(2000) =
            LEFT(
                COALESCE(
                    @ImportError,
                    CONCAT(
                        N''Error '',
                        ERROR_NUMBER(),
                        N'' in '',
                        COALESCE(ERROR_PROCEDURE(), N''UPDATE_ALL''),
                        N'' line '',
                        ERROR_LINE(),
                        N'': '',
                        COALESCE(ERROR_MESSAGE(), N''(no message)'')
                    )
                ),
                2000
            );

        IF XACT_STATE() <> 0
            ROLLBACK;

        BEGIN TRY
            UPDATE dbo.KS4_ImportFileClaim
            SET LastError = @OuterPersistedError
            WHERE CompletedFileName = @CompletedFileName
              AND ClaimStatus = N''claimed'';
        END TRY
        BEGIN CATCH
            -- Never mask the original UPDATE_ALL failure.
        END CATCH;

        SET ANSI_WARNINGS ON;
        THROW;
    END CATCH
END;';
-- dbo.v_PlayerAccounts_Migrate
EXEC sys.sp_executesql N'CREATE OR ALTER VIEW [dbo].[v_PlayerAccounts_Migrate]  AS
SELECT
    PA.GovernorID,
    COALESCE(n.GovernorName,LTRIM(RTRIM(PA.GovernorName)))           AS GovernorName,   -- fix bad LTRIM(..., 1)
    PP.Power,
    KS4.[Troops Power],
    PA.[Status],
    PA.[UpdatedAt],
    PA.[AccountType],
    PA.[Main_GovernorID],
    loc.X,
    loc.Y
FROM dbo.PlayerAccountStatus AS PA
LEFT JOIN dbo.v_ReportGovernorNames n ON n.GovernorID=PA.GovernorID
OUTER APPLY
(
    -- Latest known location for this governor (prevents duplicate rows)
    SELECT TOP (1) pl.X, pl.Y
    FROM dbo.PlayerLocation AS pl
    WHERE pl.GovernorID = PA.GovernorID
    ORDER BY pl.[LastUpdated] DESC
) AS loc
INNER JOIN dbo.v_PlayerProfile     AS PP  ON PP.GovernorID  = PA.GovernorID
INNER JOIN dbo.v_PlayerLatestStats AS KS4 ON KS4.GovernorID = PA.GovernorID
WHERE PA.[Status] = ''Migrate'';';
-- dbo.v_TARGETS_FOR_UPLOAD
EXEC sys.sp_executesql N'CREATE OR ALTER VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT t.[Rank],
t.[Gov_ID],
COALESCE(n.GovernorName,t.[Governor_Name]) AS [Governor_Name],
t.[Power],
t.[City Hall],
t.[Troops Power],
t.[Tech Power],
t.[Building Power],
t.[Commander Power],
t.[BLANK1],
t.[Kill Target],
t.[Minimum Kill Target],
t.[Dead Target],
t.[DKP Target],
t.[BLANK2],
t.[Kills KVK -1],
t.[DEADS KVK -1],
t.[DKP KVK -1],
t.[% DKP Target KVK -1],
t.[BLANK3],
t.[Kills KVK -2],
t.[DEADS KVK -2],
t.[DKP KVK -2],
t.[% DKP Target KVK -2]
FROM dbo.EXCEL_EXPORT_KVK_TARGETS_16 t LEFT JOIN dbo.v_ReportGovernorNames n ON n.GovernorID=t.Gov_ID;';
-- dbo.sp_TARGETS_MASTER
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_TARGETS_MASTER]
    @KVK [int] = NULL,
    @ForceRepublish [bit] = 0,
    @RepublishReason [nvarchar](400) = NULL,
    @ExportPreparationID uniqueidentifier = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF @ExportPreparationID IS NULL AND @@TRANCOUNT <> 0
    BEGIN
        RAISERROR(
            ''sp_TARGETS_MASTER must own its publication transaction and cannot run inside an existing transaction.'',
            16,
            1
        );
        RETURN;
    END;

    SET XACT_ABORT ON;

    -- Only the typed configuration producer may include publication in its
    -- enclosing transaction. Its business writes and completion receipt must
    -- become visible together. Ordinary callers retain the standalone contract.
    IF @ExportPreparationID IS NOT NULL
    BEGIN
        IF @@TRANCOUNT <> 1 OR XACT_STATE() <> 1
            THROW 52624, ''Atomic configuration publication requires one active caller transaction.'', 1;
        IF NOT EXISTS
        (
            SELECT 1 FROM dbo.ExportPreparation p WITH (UPDLOCK,HOLDLOCK)
            JOIN dbo.ExportResource r WITH (UPDLOCK,HOLDLOCK)
              ON r.ActivePreparationID=p.PreparationID AND r.OwnerID=p.OwnerID AND r.Fence=p.Fence
            WHERE p.PreparationID=@ExportPreparationID AND p.ConsumerKind=''scan_data''
              AND p.State=''writing'' AND p.GenerationJson IS NULL AND p.JobID IS NULL
              AND p.SpoolKey IS NULL AND p.KVK_NO IS NULL
              AND JSON_VALUE(p.RequestJson,''$.request.producer.kind'')=''configuration_import''
              AND JSON_VALUE(p.RequestJson,''$.request.producer.atomic_checkpoint'')=''1''
              AND r.ResourceKey=''sql_snapshot:legacy_outputs'' AND r.ResourceKind=''sql_snapshot''
              AND r.ActiveJobID IS NULL AND r.ActiveOutputOperationID IS NULL
        )
            THROW 52625, ''Atomic configuration publication requires its exact writing reservation.'', 1;
    END;

    DECLARE @RequestedKVK int = @KVK;

    IF @RequestedKVK IS NOT NULL AND @RequestedKVK <= 0
        THROW 52598, ''sp_TARGETS_MASTER requires a positive @KVK when one is supplied.'', 1;

    IF @ForceRepublish IS NULL
        THROW 52599, ''sp_TARGETS_MASTER requires an explicit @ForceRepublish bit value.'', 1;

    IF @ForceRepublish = 1 AND @RequestedKVK IS NULL
        THROW 52600, ''sp_TARGETS_MASTER requires an explicit @KVK when @ForceRepublish = 1.'', 1;

    IF @ForceRepublish = 1
       AND NULLIF(LTRIM(RTRIM(@RepublishReason)), N'''') IS NULL
        THROW 52601, ''sp_TARGETS_MASTER requires @RepublishReason when @ForceRepublish = 1.'', 1;

    IF @ForceRepublish = 0 AND @RepublishReason IS NOT NULL
        THROW 52602, ''sp_TARGETS_MASTER accepts @RepublishReason only when @ForceRepublish = 1.'', 1;

    IF @ForceRepublish = 1
       AND NOT EXISTS
       (
           SELECT 1
           FROM dbo.ProcConfig
           WHERE KVKVersion = @RequestedKVK
             AND ConfigKey IN (''MATCHMAKING_SCAN'', ''DRAFTSCAN'')
       )
        THROW 52619, ''sp_TARGETS_MASTER could not resolve the requested KVK before force-republish processing.'', 1;

    SET ANSI_WARNINGS OFF;

    PRINT N''DBG: sp_TARGETS_MASTER start'';

    IF @RequestedKVK IS NULL
        PRINT N''MODE: Full refresh (all KVKs)'';
    ELSE IF @ForceRepublish = 1
        PRINT CONCAT(''MODE: Forced target republish (KVK '', CAST(@RequestedKVK AS nvarchar(20)), '')'');
    ELSE
        PRINT CONCAT(''MODE: Incremental refresh (KVK '', CAST(@RequestedKVK AS nvarchar(20)), '' only)'');

    BEGIN TRY
        IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        DECLARE @CurrentKVK int;
        DECLARE @MatchedKVKCount int = 0;

        DECLARE kvk_cursor_master CURSOR LOCAL FAST_FORWARD FOR
            SELECT DISTINCT KVKVersion
            FROM dbo.ProcConfig
            WHERE ConfigKey IN (''MATCHMAKING_SCAN'', ''DRAFTSCAN'')
              AND (@RequestedKVK IS NULL OR KVKVersion = @RequestedKVK)
            ORDER BY KVKVersion;

        DECLARE @DeltaPreprocessingLockResult int;
        DECLARE @DeltaPreprocessingLockResource nvarchar(255) =
            N''K98:TargetPublication:DeltaPreprocessing'';

        EXEC @DeltaPreprocessingLockResult = sys.sp_getapplock
            @Resource = @DeltaPreprocessingLockResource,
            @LockMode = N''Exclusive'',
            @LockOwner = N''Session'',
            @LockTimeout = 60000,
            @DbPrincipal = N''public'';

        IF @DeltaPreprocessingLockResult < 0
            THROW 52622, ''sp_TARGETS_MASTER could not acquire the shared delta-preprocessing mutex.'', 1;

        BEGIN TRY
            SET ANSI_WARNINGS ON;
            PRINT N''Calling CREATE_DELTA_TABLES'';
            EXEC dbo.CREATE_DELTA_TABLES;
            SET ANSI_WARNINGS OFF;
        END TRY
        BEGIN CATCH
            EXEC sys.sp_releaseapplock
                @Resource = @DeltaPreprocessingLockResource,
                @LockOwner = N''Session'',
                @DbPrincipal = N''public'';
            THROW;
        END CATCH;

        EXEC @DeltaPreprocessingLockResult = sys.sp_releaseapplock
            @Resource = @DeltaPreprocessingLockResource,
            @LockOwner = N''Session'',
            @DbPrincipal = N''public'';

        IF @DeltaPreprocessingLockResult < 0
            THROW 52623, ''sp_TARGETS_MASTER could not release the shared delta-preprocessing mutex.'', 1;

        OPEN kvk_cursor_master;
        FETCH NEXT FROM kvk_cursor_master INTO @CurrentKVK;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF @CurrentKVK IS NULL OR @CurrentKVK <= 0
                THROW 52620, ''sp_TARGETS_MASTER found a nonpositive configured KVKVersion.'', 1;

            SET @MatchedKVKCount += 1;

            BEGIN TRY
                BEGIN TRANSACTION;

                DECLARE @PublicationLockResult int;
                DECLARE @PublicationLockResource nvarchar(255) =
                    N''K98:KVKTargetPublication:'' + CONVERT(nvarchar(20), @CurrentKVK);

                EXEC @PublicationLockResult = sys.sp_getapplock
                    @Resource = @PublicationLockResource,
                    @LockMode = N''Exclusive'',
                    @LockOwner = N''Transaction'',
                    @LockTimeout = 60000,
                    @DbPrincipal = N''public'';

                IF @PublicationLockResult < 0
                    THROW 52603, ''sp_TARGETS_MASTER could not acquire the KVK target publication mutex.'', 1;

                PRINT CONCAT(''Processing KVKVersion: '', CAST(@CurrentKVK AS nvarchar(20)));

                DECLARE @ConfiguredScanRaw float = NULL;
                DECLARE @DraftScanRaw float = NULL;
                DECLARE @ConfiguredScan int = NULL;
                DECLARE @DraftScan int = NULL;
                DECLARE @MaxAvailableScan int = NULL;
                DECLARE @Scan int = NULL;
                DECLARE @SourceScanType nvarchar(32) = NULL;
                DECLARE @PublicationState nvarchar(16) = NULL;
                DECLARE @ShouldProcess bit = 1;

                SELECT @ConfiguredScanRaw = pc.ConfigValue
                FROM dbo.ProcConfig AS pc WITH (HOLDLOCK)
                WHERE pc.KVKVersion = @CurrentKVK
                  AND pc.ConfigKey = ''MATCHMAKING_SCAN'';

                SELECT @DraftScanRaw = pc.ConfigValue
                FROM dbo.ProcConfig AS pc WITH (HOLDLOCK)
                WHERE pc.KVKVersion = @CurrentKVK
                  AND pc.ConfigKey = ''DRAFTSCAN'';

                SET @ConfiguredScan = TRY_CONVERT(int, @ConfiguredScanRaw);
                SET @DraftScan = TRY_CONVERT(int, @DraftScanRaw);

                IF @ConfiguredScanRaw IS NOT NULL
                   AND
                   (
                       @ConfiguredScan IS NULL
                       OR @ConfiguredScan <= 0
                       OR @ConfiguredScanRaw <> CONVERT(float, @ConfiguredScan)
                   )
                    THROW 52604, ''sp_TARGETS_MASTER found an invalid MATCHMAKING_SCAN configuration.'', 1;

                IF @DraftScanRaw IS NOT NULL
                   AND
                   (
                       @DraftScan IS NULL
                       OR @DraftScan <= 0
                       OR @DraftScanRaw <> CONVERT(float, @DraftScan)
                   )
                    THROW 52605, ''sp_TARGETS_MASTER found an invalid DRAFTSCAN configuration.'', 1;

                SELECT @MaxAvailableScan = MAX(ScanOrder)
                FROM dbo.KingdomScanData4;

                IF @MaxAvailableScan IS NULL
                BEGIN
                    PRINT CONCAT(''WARN: No scan data in KingdomScanData4; skipping KVK '', CAST(@CurrentKVK AS nvarchar(20)));
                    SET @ShouldProcess = 0;
                END
                ELSE IF @ConfiguredScan IS NOT NULL AND @ConfiguredScan <= @MaxAvailableScan
                BEGIN
                    SET @Scan = @ConfiguredScan;
                    SET @SourceScanType = N''MATCHMAKING_SCAN'';
                    SET @PublicationState = N''OFFICIAL'';
                    PRINT CONCAT(''Using MATCHMAKING_SCAN ('', CAST(@Scan AS varchar(30)), '') for KVK '', CAST(@CurrentKVK AS nvarchar(20)));
                END
                ELSE IF @DraftScan IS NOT NULL
                BEGIN
                    SET @Scan = CASE WHEN @DraftScan <= @MaxAvailableScan THEN @DraftScan ELSE @MaxAvailableScan END;
                    SET @SourceScanType = N''DRAFTSCAN'';
                    SET @PublicationState = N''DRAFT'';
                    PRINT CONCAT(''Using DRAFTSCAN ('', CAST(@DraftScan AS varchar(30)), '' -> applied '', CAST(@Scan AS varchar(30)), '') for KVK '', CAST(@CurrentKVK AS nvarchar(20)));
                END
                ELSE
                BEGIN
                    PRINT CONCAT(''WARN: Neither MATCHMAKING_SCAN nor DRAFTSCAN set; skipping KVK '', CAST(@CurrentKVK AS nvarchar(20)));
                    SET @ShouldProcess = 0;
                END;

                IF @ForceRepublish = 1 AND @ShouldProcess = 0
                    THROW 52606, ''sp_TARGETS_MASTER cannot force-republish without an available configured source scan.'', 1;

                IF @ShouldProcess = 1
                   AND NOT EXISTS
                   (
                       SELECT 1
                       FROM dbo.KingdomScanData4
                       WHERE ScanOrder = @Scan
                   )
                    THROW 52607, ''sp_TARGETS_MASTER could not prove rows for the exact selected source scan.'', 1;

                DECLARE @CurrentPublicationState nvarchar(16) = NULL;
                DECLARE @CurrentSourceScanOrder int = NULL;
                DECLARE @CurrentConfiguredMatchmakingScan int = NULL;

                SELECT
                    @CurrentPublicationState = p.PublicationState,
                    @CurrentSourceScanOrder = p.SourceScanOrder,
                    @CurrentConfiguredMatchmakingScan = p.ConfiguredMatchmakingScan
                FROM dbo.KVK_Target_Publication AS p WITH (UPDLOCK, HOLDLOCK)
                WHERE p.KVK_NO = @CurrentKVK
                  AND p.IsCurrent = 1;

                IF @ForceRepublish = 1
                   AND ISNULL(@CurrentPublicationState, N'''') <> N''OFFICIAL''
                    THROW 52608, ''sp_TARGETS_MASTER permits force-republish only for an existing Official publication.'', 1;

                IF @ForceRepublish = 1
                   AND ISNULL(@SourceScanType, N'''') <> N''MATCHMAKING_SCAN''
                    THROW 52609, ''sp_TARGETS_MASTER permits force-republish only from the exact configured MATCHMAKING_SCAN.'', 1;

                IF @CurrentPublicationState = N''OFFICIAL''
                   AND @ForceRepublish = 0
                   AND
                   (
                       @ConfiguredScan IS NULL
                       OR @CurrentConfiguredMatchmakingScan <> @ConfiguredScan
                       OR @CurrentSourceScanOrder <> @ConfiguredScan
                   )
                    THROW 52610, ''sp_TARGETS_MASTER found MATCHMAKING_SCAN drift for an existing Official publication; operator review is required.'', 1;

                IF @ShouldProcess = 1
                   AND @CurrentPublicationState = N''OFFICIAL''
                   AND @ForceRepublish = 0
                BEGIN
                    IF @SourceScanType <> N''MATCHMAKING_SCAN''
                        THROW 52621, ''sp_TARGETS_MASTER could not reselect the Official publication MATCHMAKING_SCAN; operator review is required.'', 1;

                    PRINT CONCAT(
                        ''Official targets already published for KVK '',
                        CAST(@CurrentKVK AS nvarchar(20)),
                        '' from scan '',
                        CAST(@CurrentSourceScanOrder AS nvarchar(20)),
                        ''; target generation and publication are unchanged.''
                    );

                    BEGIN TRY
                        EXEC dbo.sp_ExcelOutput_ByKVK @CurrentKVK, @CurrentSourceScanOrder;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT(''ERR: sp_ExcelOutput_ByKVK failed while preserving Official targets: '', ISNULL(ERROR_MESSAGE(), ''(no message)''));
                        THROW;
                    END CATCH;

                    SET @ShouldProcess = 0;
                END;

                IF @ShouldProcess = 1
                BEGIN
                    PRINT CONCAT(''Publishing KVK '', CAST(@CurrentKVK AS varchar(20)), '' with SCANORDER = '', CAST(@Scan AS varchar(30)));

                    BEGIN TRY
                        EXEC dbo.sp_Prep_TargetTable @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT(''ERR: sp_Prep_TargetTable failed: '', ISNULL(ERROR_MESSAGE(), ''(no message)''));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_ExcelOutput_ByKVK @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT(''ERR: sp_ExcelOutput_ByKVK failed: '', ISNULL(ERROR_MESSAGE(), ''(no message)''));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_Prep_ExcelOutputTable @CurrentKVK, @Scan;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT(''ERR: sp_Prep_ExcelOutputTable failed: '', ISNULL(ERROR_MESSAGE(), ''(no message)''));
                        THROW;
                    END CATCH;

                    BEGIN TRY
                        EXEC dbo.sp_Prep_ExcelExportTable @CurrentKVK;
                    END TRY
                    BEGIN CATCH
                        PRINT CONCAT(''ERR: sp_Prep_ExcelExportTable failed: '', ISNULL(ERROR_MESSAGE(), ''(no message)''));
                        THROW;
                    END CATCH;

                    DECLARE @ExportTableName sysname =
                        N''EXCEL_EXPORT_KVK_TARGETS_'' + CONVERT(nvarchar(20), @CurrentKVK);
                    DECLARE @ExportObjectName nvarchar(257) =
                        N''dbo.'' + @ExportTableName;
                    DECLARE @ExportTableQuoted nvarchar(300) =
                        QUOTENAME(N''dbo'') + N''.'' + QUOTENAME(@ExportTableName);

                    IF OBJECT_ID(@ExportObjectName, N''U'') IS NULL
                        THROW 52611, ''sp_TARGETS_MASTER could not find the generated target export object.'', 1;

                    DECLARE @TargetRowCount int = NULL;
                    DECLARE @InvalidTargetRowCount int = NULL;
                    DECLARE @CountSql nvarchar(max) = N''
                        SELECT
                            @RowCountOut = COUNT(*),
                            @InvalidCountOut = COALESCE(SUM
                            (
                                CASE
                                    WHEN [Gov_ID] IS NULL
                                      OR TRY_CONVERT(bigint, [Gov_ID]) IS NULL
                                      OR CONVERT(float, TRY_CONVERT(bigint, [Gov_ID])) <> [Gov_ID]
                                      OR TRY_CONVERT(bigint, [Gov_ID]) <= 0
                                      OR [Kill Target] < 0
                                      OR [Minimum Kill Target] < 0
                                      OR [Dead Target] < 0
                                      OR [DKP Target] < 0
                                        THEN 1
                                    ELSE 0
                                END
                            ), 0)
                        FROM '' + @ExportTableQuoted + N'';'';

                    EXEC sys.sp_executesql
                        @CountSql,
                        N''@RowCountOut int OUTPUT, @InvalidCountOut int OUTPUT'',
                        @RowCountOut = @TargetRowCount OUTPUT,
                        @InvalidCountOut = @InvalidTargetRowCount OUTPUT;

                    IF ISNULL(@TargetRowCount, 0) <= 0
                        THROW 52612, ''sp_TARGETS_MASTER refused to publish an empty target set.'', 1;

                    IF ISNULL(@InvalidTargetRowCount, 0) <> 0
                        THROW 52613, ''sp_TARGETS_MASTER refused target rows with invalid identity or target values.'', 1;

                    SET ANSI_WARNINGS ON;
                    SET ANSI_PADDING ON;
                    SET ARITHABORT ON;
                    SET CONCAT_NULL_YIELDS_NULL ON;
                    SET NUMERIC_ROUNDABORT OFF;

                    DECLARE @PublicationVersion int;
                    DECLARE @PublicationSignature uniqueidentifier = NEWID();
                    DECLARE @PublishedAtUtc datetime2(3) = SYSUTCDATETIME();
                    DECLARE @PublishedBy nvarchar(128) =
                        LEFT(COALESCE(ORIGINAL_LOGIN(), SUSER_SNAME(), N''unknown''), 128);

                    SELECT @PublicationVersion = ISNULL(MAX(p.PublicationVersion), 0) + 1
                    FROM dbo.KVK_Target_Publication AS p WITH (UPDLOCK, HOLDLOCK)
                    WHERE p.KVK_NO = @CurrentKVK;

                    INSERT dbo.KVK_Target_Publication
                    (
                        KVK_NO,
                        PublicationState,
                        SourceScanOrder,
                        SourceScanType,
                        ConfiguredDraftScan,
                        ConfiguredMatchmakingScan,
                        PublishedAtUtc,
                        TargetRowCount,
                        OutputObjectName,
                        PublicationVersion,
                        PublicationSignature,
                        IsCurrent,
                        ForcedRepublish,
                        RepublishReason,
                        PublishedBy
                    )
                    VALUES
                    (
                        @CurrentKVK,
                        @PublicationState,
                        @Scan,
                        @SourceScanType,
                        @DraftScan,
                        @ConfiguredScan,
                        @PublishedAtUtc,
                        @TargetRowCount,
                        @ExportObjectName,
                        @PublicationVersion,
                        @PublicationSignature,
                        0,
                        @ForceRepublish,
                        CASE WHEN @ForceRepublish = 1 THEN LTRIM(RTRIM(@RepublishReason)) ELSE NULL END,
                        @PublishedBy
                    );

                    DECLARE @NewPublicationId bigint = SCOPE_IDENTITY();
                    DECLARE @CopySql nvarchar(max) = N''
                        INSERT dbo.KVK_Target_Publication_Row
                        (
                            PublicationId,
                            GovernorID,
                            TargetRank,
                            GovernorName,
                            Power,
                            KillTarget,
                            MinimumKillTarget,
                            DeadTarget,
                            DKPTarget
                        )
                        SELECT
                            @PublicationId,
                            CONVERT(bigint, [Gov_ID]),
                            [Rank],
                            [Governor_Name],
                            [Power],
                            [Kill Target],
                            [Minimum Kill Target],
                            [Dead Target],
                            [DKP Target]
                        FROM '' + @ExportTableQuoted + N'';'';

                    EXEC sys.sp_executesql
                        @CopySql,
                        N''@PublicationId bigint'',
                        @PublicationId = @NewPublicationId;

                    IF
                    (
                        SELECT COUNT(*)
                        FROM dbo.KVK_Target_Publication_Row
                        WHERE PublicationId = @NewPublicationId
                    ) <> @TargetRowCount
                        THROW 52614, ''sp_TARGETS_MASTER target snapshot row count did not match the generated output.'', 1;

                    UPDATE dbo.KVK_Target_Publication
                    SET IsCurrent = 0
                    WHERE KVK_NO = @CurrentKVK
                      AND IsCurrent = 1;

                    UPDATE dbo.KVK_Target_Publication
                    SET IsCurrent = 1
                    WHERE PublicationId = @NewPublicationId;

                    IF @@ROWCOUNT <> 1
                        THROW 52615, ''sp_TARGETS_MASTER could not make exactly one target publication current.'', 1;

                    IF OBJECT_ID(N''dbo.v_TARGETS_FOR_UPLOAD'', N''U'') IS NOT NULL
                        THROW 52616, ''sp_TARGETS_MASTER refused to replace a table named dbo.v_TARGETS_FOR_UPLOAD.'', 1;

                    -- Preserve the shared display-name rule when rollover replaces
                    -- this view. Keep the selected publication table and column order.
                    DECLARE @LegacyNameColumns nvarchar(max);
                    SELECT @LegacyNameColumns=STRING_AGG(CONVERT(nvarchar(max),
                        CASE WHEN c.name=N''Governor_Name''
                             THEN N''COALESCE(n.GovernorName,t.[Governor_Name]) AS [Governor_Name]''
                             ELSE N''t.''+QUOTENAME(c.name) END),N'','')
                        WITHIN GROUP (ORDER BY c.column_id)
                    FROM sys.columns c WHERE c.object_id=OBJECT_ID(@ExportTableQuoted);
                    IF @LegacyNameColumns IS NULL
                        THROW 52971, ''Target report column projection is unavailable.'', 1;
                    DECLARE @LegacyViewSql nvarchar(max) =
                        N''CREATE OR ALTER VIEW dbo.v_TARGETS_FOR_UPLOAD AS SELECT ''
                        + @LegacyNameColumns + N'' FROM '' + @ExportTableQuoted
                        + N'' t LEFT JOIN dbo.v_ReportGovernorNames n ON n.GovernorID=t.Gov_ID;'';

                    EXEC sys.sp_executesql @LegacyViewSql;

                    IF
                    (
                        SELECT COUNT(*)
                        FROM dbo.v_KVK_TARGETS_FOR_BOT
                        WHERE KVK_NO = @CurrentKVK
                          AND PublicationId = @NewPublicationId
                          AND PublicationVersion = @PublicationVersion
                          AND PublicationSignature = @PublicationSignature
                    ) <> @TargetRowCount
                        THROW 52617, ''sp_TARGETS_MASTER bot-facing publication view failed post-publication validation.'', 1;

                    PRINT CONCAT(
                        ''Published '',
                        @PublicationState,
                        '' targets for KVK '',
                        CAST(@CurrentKVK AS nvarchar(20)),
                        '' from '',
                        @SourceScanType,
                        '' scan '',
                        CAST(@Scan AS nvarchar(20)),
                        '' as publication version '',
                        CAST(@PublicationVersion AS nvarchar(20)),
                        '' with '',
                        CAST(@TargetRowCount AS nvarchar(20)),
                        '' rows.''
                    );
                END;

                COMMIT TRANSACTION;
            END TRY
            BEGIN CATCH
                IF XACT_STATE() <> 0
                    ROLLBACK TRANSACTION;

                THROW;
            END CATCH;

            FETCH NEXT FROM kvk_cursor_master INTO @CurrentKVK;
        END;

        IF @ForceRepublish = 1 AND @MatchedKVKCount <> 1
            THROW 52618, ''sp_TARGETS_MASTER could not resolve exactly one configured KVK for force-republish.'', 1;

        IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        SET ANSI_WARNINGS ON;
        IF @ExportPreparationID IS NOT NULL AND (@@TRANCOUNT <> 1 OR XACT_STATE() <> 1)
            THROW 52626, ''Atomic configuration publication lost its caller transaction.'', 1;
        PRINT N''DBG: sp_TARGETS_MASTER complete'';
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''global'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;
        IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') >= -1
        BEGIN
            IF CURSOR_STATUS(''local'', ''kvk_cursor_master'') = 0 CLOSE kvk_cursor_master;
            DEALLOCATE kvk_cursor_master;
        END;

        SET ANSI_WARNINGS ON;

        DECLARE @ErrMsg nvarchar(2048) = ERROR_MESSAGE();
        DECLARE @ErrProc sysname = ERROR_PROCEDURE();
        DECLARE @ErrLine int = ERROR_LINE();

        PRINT CONCAT(
            N''ERROR in sp_TARGETS_MASTER: '',
            ISNULL(@ErrProc, N''(no procedure)''),
            N'' line '',
            CAST(ISNULL(@ErrLine, 0) AS nvarchar(10)),
            N'': '',
            ISNULL(@ErrMsg, N''(no message)'')
        );

        THROW;
    END CATCH;
END';
-- dbo.sp_ExcelOutput_ByKVK
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[sp_ExcelOutput_ByKVK]
	@KVK [int],
	@Scan [int]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
	SET XACT_ABORT ON;

    DECLARE 
        @CURRENTKVK3      INT,
        @KVK_END_SCAN     INT,
        @LASTKVKEND       INT,
        @PASS4END         INT,
        @PASS6END         INT,
        @PASS7END         INT,
        @PRE_PASS_4_SCAN  INT,
        @MaxAvailableScan INT,
        @LatestScanToUse  INT;

    -- Load KVK config
    SELECT
        @CURRENTKVK3     = CAST(MAX(CASE WHEN ConfigKey = ''CURRENTKVK3''     THEN ConfigValue END) AS INT),
        @KVK_END_SCAN    = CAST(MAX(CASE WHEN ConfigKey = ''KVK_END_SCAN''    THEN ConfigValue END) AS INT),
        @LASTKVKEND      = CAST(MAX(CASE WHEN ConfigKey = ''LASTKVKEND''      THEN ConfigValue END) AS INT),
        @PASS4END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS4END''        THEN ConfigValue END) AS INT),
        @PASS6END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS6END''        THEN ConfigValue END) AS INT),
        @PASS7END        = CAST(MAX(CASE WHEN ConfigKey = ''PASS7END''        THEN ConfigValue END) AS INT),
        @PRE_PASS_4_SCAN = CAST(MAX(CASE WHEN ConfigKey = ''PRE_PASS_4_SCAN'' THEN ConfigValue END) AS INT)
    FROM dbo.ProcConfig
    WHERE KVKVersion = @KVK;

    IF @KVK_END_SCAN IS NULL OR @LASTKVKEND IS NULL OR @PRE_PASS_4_SCAN IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Missing KVK window config for KVK=%d (one of KVK_END_SCAN/LASTKVKEND/PRE_PASS_4_SCAN is NULL).'', 16, 1, @KVK);
        RETURN;
    END

    -- Cap @Scan to available data (safety if caller passed a future scan)
    SELECT @MaxAvailableScan = MAX(ScanOrder) FROM dbo.KingdomScanData4;
    IF @MaxAvailableScan IS NULL
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: No scan data available.'', 16, 1);
        RETURN;
    END
    IF @Scan > @MaxAvailableScan SET @Scan = @MaxAvailableScan;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @Scan
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Requested final ScanOrder=%d has no source rows.'', 16, 1, @Scan);
        RETURN;
    END

    -- Determine which scan to use for latest data
    -- For completed KVKs use KVK_END_SCAN, for current KVK use MaxAvailableScan
    SET @LatestScanToUse = CASE 
        WHEN @MaxAvailableScan > @KVK_END_SCAN THEN @KVK_END_SCAN
        ELSE @MaxAvailableScan
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.KingdomScanData4
        WHERE ScanOrder = @LatestScanToUse
    )
    BEGIN
        RAISERROR(''sp_ExcelOutput_ByKVK: Resolved final ScanOrder=%d has no source rows.'', 16, 1, @LatestScanToUse);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Fresh staging
        TRUNCATE TABLE dbo.STAGING_STATS;

    -----------------------------------------------
    -- Build/refresh ranked PreKvk & Honor tables (so we can join ranks quickly)
    -----------------------------------------------
    EXEC dbo.sp_Build_Prekvk_And_Honor_Rankings;

    -----------------------------------------------
     -- 1. Snapshot (materialize once for reuse) - REDUCED COLUMNS
    -----------------------------------------------
    CREATE TABLE #Snapshot (
        GovernorID        bigint           NOT NULL PRIMARY KEY CLUSTERED,
        GovernorName      nvarchar(255)  NULL,
        PowerRank         int           NULL,
        [Power]           bigint        NULL,
        [Civilization]    nvarchar(100)  NULL,
        [KvKPlayed]       int           NULL,
        [Deads]           bigint        NULL,
        [T4&T5_KILLS]     bigint        NULL,
        [HealedTroops]    bigint        NULL,
        [KillPoints]      bigint        NULL,
        [AutarchTimes]    bigint        NULL,
        MaxPreKvkPoints   bigint        NULL,
        PreKvkRank        int           NULL,
        MaxHonorPoints    bigint        NULL,
        HonorRank         int           NULL,
		RangedPoints     bigint  NULL
    );

    INSERT INTO #Snapshot (
          GovernorID
        , GovernorName
        , PowerRank
        , [Power]
        , [Civilization]
        , [KvKPlayed]
        , [Deads]
        , [T4&T5_KILLS]
        , [HealedTroops]
        , [KillPoints]
        , [AutarchTimes]
        , MaxPreKvkPoints
        , PreKvkRank
        , MaxHonorPoints
        , HonorRank
		, RangedPoints
    )
    SELECT
        ksd.GovernorID,
        ksd.GovernorName,
        ksd.PowerRank,
        ksd.[Power],
        ksd.[Civilization],
        ksd.[KvKPlayed],
		ksd.[Deads],
		ksd.[T4&T5_KILLS], 
		ksd.[HealedTroops], 
		ksd.[KillPoints],
		ksd.[AutarchTimes],
        pk.MaxPreKvkPoints    AS MaxPreKvkPoints,
        pk.PreKvk_Rank        AS PreKvkRank,
        hn.MaxHonorPoints     AS MaxHonorPoints,
        hn.Honor_Rank         AS HonorRank,
		ksd.[RangedPoints]
    FROM dbo.KingdomScanData4 ksd
    LEFT JOIN dbo.PreKvk_Scores_Ranked pk
      ON pk.GovernorID = ksd.GovernorID AND pk.KVK_NO = @CURRENTKVK3
    LEFT JOIN dbo.KVK_Honor_Ranked hn
      ON hn.GovernorID = ksd.GovernorID AND hn.KVK_NO = @CURRENTKVK3
    WHERE ksd.ScanOrder = @Scan;

    -----------------------------------------------
    -- 1b. LATEST data (for completed/current KVK stats)
    -----------------------------------------------
    CREATE TABLE #LATEST (
        GovernorID       bigint  NOT NULL PRIMARY KEY CLUSTERED,
        MostKvKKill      bigint  NULL,
        MostKvKDead      bigint  NULL,
        MostKvKHeal      bigint  NULL,
        Acclaim          bigint  NULL,
        HighestAcclaim   bigint  NULL,
        AOOJoined        bigint  NULL,
        AOOWon           int     NULL,
        AOOAvgKill       bigint  NULL,
        AOOAvgDead       bigint  NULL,
        AOOAvgHeal       bigint  NULL,
        Conduct          decimal(5,2) NULL
    );

    INSERT INTO #LATEST (
          GovernorID
        , MostKvKKill
        , MostKvKDead
        , MostKvKHeal
        , Acclaim
        , HighestAcclaim
        , AOOJoined
        , AOOWon
        , AOOAvgKill
        , AOOAvgDead
        , AOOAvgHeal
        , Conduct
    )
    SELECT
        ksd.GovernorID,
        ksd.MostKvKKill,
        ksd.MostKvKDead,
        ksd.MostKvKHeal,
        ksd.Acclaim,
        ksd.HighestAcclaim,
        ksd.AOOJoined,
        ksd.AOOWon,
        ksd.AOOAvgKill,
        ksd.AOOAvgDead,
        ksd.AOOAvgHeal,
        ksd.Conduct
    FROM dbo.KingdomScanData4 ksd
    WHERE ksd.ScanOrder = @LatestScanToUse;

	CREATE TABLE #GovernorList (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED
    );

    INSERT INTO #GovernorList (GovernorID)
    SELECT s.GovernorID
    FROM #Snapshot s
    WHERE s.GovernorID IS NOT NULL;

    -----------------------------------------------
    -- 2. Consolidated Deads Delta (filtered to snapshot)
    -----------------------------------------------
    CREATE TABLE #Deads (
        GovernorID        bigint  NOT NULL PRIMARY KEY CLUSTERED,
        DeadsDelta        bigint  NOT NULL,
        DeadsDeltaOutKVK  bigint  NOT NULL,
        P4DeadsDelta      bigint  NOT NULL,
        P6DeadsDelta      bigint  NOT NULL,
        P7DeadsDelta      bigint  NOT NULL,
        P8DeadsDelta      bigint  NOT NULL
    );

    INSERT INTO #Deads (GovernorID, DeadsDelta, DeadsDeltaOutKVK, P4DeadsDelta, P6DeadsDelta, P7DeadsDelta, P8DeadsDelta)
    SELECT 
        d.GovernorID,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @LASTKVKEND      AND d.DeltaOrder <= @PRE_PASS_4_SCAN THEN d.DeadsDelta ELSE 0 END) AS DeadsDeltaOutKVK,
        SUM(CASE WHEN d.DeltaOrder > @PRE_PASS_4_SCAN AND d.DeltaOrder <= @PASS4END THEN d.DeadsDelta ELSE 0 END) AS P4DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS4END        AND d.DeltaOrder <= @PASS6END THEN d.DeadsDelta ELSE 0 END) AS P6DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS6END        AND d.DeltaOrder <= @PASS7END THEN d.DeadsDelta ELSE 0 END) AS P7DeadsDelta,
        SUM(CASE WHEN d.DeltaOrder > @PASS7END        AND d.DeltaOrder <= @KVK_END_SCAN THEN d.DeadsDelta ELSE 0 END) AS P8DeadsDelta
    FROM dbo.DeadsDelta d
    INNER JOIN #GovernorList gl ON gl.GovernorID = d.GovernorID
    WHERE d.DeltaOrder > @LASTKVKEND AND d.DeltaOrder <= @KVK_END_SCAN
    GROUP BY d.GovernorID;

    -----------------------------------------------
    -- 3. Consolidated Kills Delta (T4&T5)
    -----------------------------------------------
    CREATE TABLE #Kills (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4T5KillsDelta  bigint  NOT NULL,
        KillsOutsideKVK bigint  NOT NULL,
        P4Kills         bigint  NOT NULL,
        P6Kills         bigint  NOT NULL,
        P7Kills         bigint  NOT NULL,
        P8Kills         bigint  NOT NULL
    );

    INSERT INTO #Kills (GovernorID, T4T5KillsDelta, KillsOutsideKVK, P4Kills, P6Kills, P7Kills, P8Kills)
    SELECT 
        k.GovernorID,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS T4T5KillsDelta,
        SUM(CASE WHEN k.DeltaOrder > @LASTKVKEND      AND k.DeltaOrder <= @PRE_PASS_4_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS KillsOutsideKVK,
        SUM(CASE WHEN k.DeltaOrder > @PRE_PASS_4_SCAN AND k.DeltaOrder <= @PASS4END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P4Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS4END        AND k.DeltaOrder <= @PASS6END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P6Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS6END        AND k.DeltaOrder <= @PASS7END THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P7Kills,
        SUM(CASE WHEN k.DeltaOrder > @PASS7END        AND k.DeltaOrder <= @KVK_END_SCAN THEN k.[T4&T5_KILLSDelta] ELSE 0 END) AS P8Kills
    FROM dbo.T4T5KillDelta k
    INNER JOIN #GovernorList gl ON gl.GovernorID = k.GovernorID
    WHERE k.DeltaOrder > @LASTKVKEND AND k.DeltaOrder <= @KVK_END_SCAN
    GROUP BY k.GovernorID;

    -----------------------------------------------
    -- 4. T4 / T5 splits
    -----------------------------------------------
    CREATE TABLE #KillsT4 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T4KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT4 (GovernorID, T4KillsDelta)
    SELECT t4.GovernorID, SUM(COALESCE(t4.T4KILLSDelta, 0)) AS T4KillsDelta
    FROM dbo.T4KillDelta t4
    INNER JOIN #GovernorList gl ON gl.GovernorID = t4.GovernorID
    WHERE t4.DeltaOrder > @PRE_PASS_4_SCAN AND t4.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t4.GovernorID;

    CREATE TABLE #KillsT5 (
        GovernorID   bigint  NOT NULL PRIMARY KEY CLUSTERED,
        T5KillsDelta bigint  NOT NULL
    );

    INSERT INTO #KillsT5 (GovernorID, T5KillsDelta)
    SELECT t5.GovernorID, SUM(COALESCE(t5.T5KILLSDelta, 0)) AS T5KillsDelta
    FROM dbo.T5KillDelta t5
    INNER JOIN #GovernorList gl ON gl.GovernorID = t5.GovernorID
    WHERE t5.DeltaOrder > @PRE_PASS_4_SCAN AND t5.DeltaOrder <= @KVK_END_SCAN
    GROUP BY t5.GovernorID;

	----------------------------------------------- 
	-- 5. KillPointsDelta aggregation (use same window as other deltas) 
	----------------------------------------------- 
    CREATE TABLE #KillPoints (
        GovernorID      bigint  NOT NULL PRIMARY KEY CLUSTERED,
        KillPointsDelta bigint  NOT NULL
    );

	INSERT INTO #KillPoints (GovernorID, KillPointsDelta)
	SELECT kp.GovernorID, SUM(COALESCE(kp.KillPointsDelta, 0)) AS KillPointsDelta
	FROM dbo.KillPointsDelta kp
    INNER JOIN #GovernorList gl ON gl.GovernorID = kp.GovernorID
	WHERE kp.DeltaOrder > @PRE_PASS_4_SCAN AND kp.DeltaOrder <= @KVK_END_SCAN 
	GROUP BY kp.GovernorID;

    -----------------------------------------------
    -- 6. Other deltas (use @Scan as lower bound)
    -----------------------------------------------
    CREATE TABLE #Helps (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        HelpsDelta bigint NOT NULL
    );

    INSERT INTO #Helps (GovernorID, HelpsDelta)
    SELECT h.GovernorID, SUM(COALESCE(h.HelpsDelta, 0)) AS HelpsDelta
    FROM dbo.HelpsDelta h
    INNER JOIN #GovernorList gl ON gl.GovernorID = h.GovernorID
    WHERE h.DeltaOrder > @Scan AND h.DeltaOrder <= @KVK_END_SCAN
    GROUP BY h.GovernorID;

    CREATE TABLE #RSSAssist (
        GovernorID     bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSAssistDelta bigint NOT NULL
    );

    INSERT INTO #RSSAssist (GovernorID, RSSAssistDelta)
    SELECT ra.GovernorID, SUM(COALESCE(ra.RSSASSISTDelta, 0)) AS RSSAssistDelta
    FROM dbo.RSSASSISTDelta ra
    INNER JOIN #GovernorList gl ON gl.GovernorID = ra.GovernorID
    WHERE ra.DeltaOrder > @Scan AND ra.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ra.GovernorID;

    CREATE TABLE #RSSGathered (
        GovernorID       bigint NOT NULL PRIMARY KEY CLUSTERED,
        RSSGatheredDelta bigint NOT NULL
    );

    INSERT INTO #RSSGathered (GovernorID, RSSGatheredDelta)
    SELECT rg.GovernorID, SUM(COALESCE(rg.RSSGatheredDelta, 0)) AS RSSGatheredDelta
    FROM dbo.RSSGatheredDelta rg
    INNER JOIN #GovernorList gl ON gl.GovernorID = rg.GovernorID
    WHERE rg.DeltaOrder > @Scan AND rg.DeltaOrder <= @KVK_END_SCAN
    GROUP BY rg.GovernorID;

    CREATE TABLE #Power (
        GovernorID bigint NOT NULL PRIMARY KEY CLUSTERED,
        PowerDelta bigint NOT NULL
    );

    INSERT INTO #Power (GovernorID, PowerDelta)
    SELECT p.GovernorID, SUM(COALESCE(p.Power_Delta, 0)) AS PowerDelta
    FROM dbo.PowerDelta p
    INNER JOIN #GovernorList gl ON gl.GovernorID = p.GovernorID
    WHERE p.DeltaOrder > @Scan AND p.DeltaOrder <= @KVK_END_SCAN
    GROUP BY p.GovernorID;

    CREATE TABLE #Healed (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        HealedTroopsDelta bigint NOT NULL
    );

	INSERT INTO #Healed (GovernorID, HealedTroopsDelta)
    SELECT ht.GovernorID, SUM(COALESCE(ht.HealedTroopsDelta, 0)) AS HealedTroopsDelta
    FROM dbo.HealedTroopsDelta ht
    INNER JOIN #GovernorList gl ON gl.GovernorID = ht.GovernorID
    WHERE ht.DeltaOrder > @PRE_PASS_4_SCAN AND ht.DeltaOrder <= @KVK_END_SCAN
    GROUP BY ht.GovernorID;

    CREATE TABLE #Ranged (
        GovernorID        bigint NOT NULL PRIMARY KEY CLUSTERED,
        RangedPointsDelta bigint NOT NULL
    );

	INSERT INTO #Ranged (GovernorID, RangedPointsDelta)
    SELECT r.GovernorID, SUM(COALESCE(r.RangedPointsDelta, 0)) AS RangedPointsDelta
    FROM dbo.RangedPointsDelta r
    INNER JOIN #GovernorList gl ON gl.GovernorID = r.GovernorID
    WHERE r.DeltaOrder > @Scan AND r.DeltaOrder <= @KVK_END_SCAN
    GROUP BY r.GovernorID;

    -----------------------------------------------
    -- 7. Stage - NOW USING #LATEST FOR MOVED COLUMNS
    -----------------------------------------------
	INSERT INTO dbo.STAGING_STATS (
		  GovernorID
		, PowerRank
		, [Power]
		, Power_Delta
		, GovernorName
		, T4KillsDelta
		, T5KillsDelta
		, [T4&T5_KILLSDelta]
		, [KILLS_OUTSIDE_KVK]
		, [P4T4&T5_KILLSDelta]
		, [P6T4&T5_KillsDelta]
		, [P7T4&T5_KillsDelta]
		, [P8T4&T5_KillsDelta]
		, DeadsDelta
		, [DEADS_OUTSIDE_KVK]
		, P4DeadsDelta
		, P6DeadsDelta
		, P7DeadsDelta
		, P8DeadsDelta
		, HelpsDelta
		, RSSASSISTDelta
		, RSSGatheredDelta
		, HealedTroops
		, RangedPoints
		, RangedPointsDelta
		, AutarchTimes
		, Civilization
		, KvKPlayed
		, MostKvKKill
		, MostKvKDead
		, MostKvKHeal
		, Acclaim
		, HighestAcclaim
		, AOOJoined
		, AOOWon
		, AOOAvgKill
		, AOOAvgDead
		, AOOAvgHeal
		, Conduct
		, KillPointsDelta
		, KillPoints
		, HealedTroopsDelta
		, [Starting_Deads]
		, [Starting_T4&T5_KILLS]
		, MaxPreKvkPoints
		, MaxHonorPoints
		, PreKvkRank
		, HonorRank
	)
	SELECT
		  s.GovernorID
		, s.PowerRank
		, s.[Power]
		, COALESCE(p.PowerDelta, 0)                 AS Power_Delta
		, s.GovernorName
		, COALESCE(kt4.T4KillsDelta, 0)             AS T4KillsDelta
		, COALESCE(kt5.T5KillsDelta, 0)             AS T5KillsDelta
		, COALESCE(k.T4T5KillsDelta, 0)             AS [T4&T5_KILLSDelta]
		, COALESCE(k.KillsOutsideKVK, 0)            AS [KILLS_OUTSIDE_KVK]
		, COALESCE(k.P4Kills, 0)                    AS [P4T4&T5_KILLSDelta]
		, COALESCE(k.P6Kills, 0)                    AS [P6T4&T5_KillsDelta]
		, COALESCE(k.P7Kills, 0)                    AS [P7T4&T5_KillsDelta]
		, COALESCE(k.P8Kills, 0)                    AS [P8T4&T5_KillsDelta]
		, COALESCE(d.DeadsDelta, 0)                 AS DeadsDelta
		, COALESCE(d.DeadsDeltaOutKVK, 0)           AS [DEADS_OUTSIDE_KVK]
		, COALESCE(d.P4DeadsDelta, 0)               AS P4DeadsDelta
		, COALESCE(d.P6DeadsDelta, 0)               AS P6DeadsDelta
		, COALESCE(d.P7DeadsDelta, 0)               AS P7DeadsDelta
		, COALESCE(d.P8DeadsDelta, 0)               AS P8DeadsDelta
		, COALESCE(h.HelpsDelta, 0)                 AS HelpsDelta
		, COALESCE(ra.RSSAssistDelta, 0)            AS RSSASSISTDelta
		, COALESCE(rg.RSSGatheredDelta, 0)          AS RSSGatheredDelta
		, COALESCE(s.HealedTroops, 0)               AS HealedTroops
		, COALESCE(s.RangedPoints, 0)             AS RangedPoints        
		, COALESCE(ran.RangedPointsDelta, 0)        AS RangedPointsDelta
		, COALESCE(s.AutarchTimes, 0)               AS AutarchTimes
		, s.Civilization
		, COALESCE(s.KvKPlayed, 0)                  AS KvKPlayed
		, COALESCE(lst.MostKvKKill, 0)              AS MostKvKKill        -- FROM #LATEST
		, COALESCE(lst.MostKvKDead, 0)              AS MostKvKDead        -- FROM #LATEST
		, COALESCE(lst.MostKvKHeal, 0)              AS MostKvKHeal        -- FROM #LATEST
		, COALESCE(lst.Acclaim, 0)                  AS Acclaim            -- FROM #LATEST
		, COALESCE(lst.HighestAcclaim, 0)           AS HighestAcclaim     -- FROM #LATEST
		, COALESCE(lst.AOOJoined, 0)                AS AOOJoined          -- FROM #LATEST
		, COALESCE(lst.AOOWon, 0)                   AS AOOWon             -- FROM #LATEST
		, COALESCE(lst.AOOAvgKill, 0)               AS AOOAvgKill         -- FROM #LATEST
		, COALESCE(lst.AOOAvgDead, 0)               AS AOOAvgDead         -- FROM #LATEST
		, COALESCE(lst.AOOAvgHeal, 0)               AS AOOAvgHeal         -- FROM #LATEST
		, lst.Conduct                                AS Conduct            -- FROM #LATEST
		, COALESCE(kp.KillPointsDelta, 0)           AS KillPointsDelta
		, COALESCE(s.KillPoints, 0)                 AS KillPoints
		, COALESCE(he.HealedTroopsDelta, 0)         AS HealedTroopsDelta
		, COALESCE(s.Deads, 0)                      AS [Starting_Deads]
		, COALESCE(s.[T4&T5_KILLS], 0)              AS [Starting_T4&T5_KILLS]
		, COALESCE(s.MaxPreKvkPoints, 0)            AS MaxPreKvkPoints
		, COALESCE(s.MaxHonorPoints, 0)             AS MaxHonorPoints
		, COALESCE(s.PreKvkRank, 0)                 AS PreKvkRank
		, COALESCE(s.HonorRank, 0)                  AS HonorRank
	FROM #Snapshot s
	LEFT JOIN #LATEST      lst ON lst.GovernorID = s.GovernorID  -- NEW JOIN
	LEFT JOIN #Power       p   ON p.GovernorID   = s.GovernorID
	LEFT JOIN #KillsT4     kt4 ON kt4.GovernorID = s.GovernorID
	LEFT JOIN #KillsT5     kt5 ON kt5.GovernorID = s.GovernorID
	LEFT JOIN #Kills       k   ON k.GovernorID   = s.GovernorID
	LEFT JOIN #KillPoints  kp  ON kp.GovernorID  = s.GovernorID
	LEFT JOIN #Deads       d   ON d.GovernorID   = s.GovernorID
	LEFT JOIN #Helps       h   ON h.GovernorID   = s.GovernorID
	LEFT JOIN #RSSAssist   ra  ON ra.GovernorID  = s.GovernorID
	LEFT JOIN #RSSGathered rg  ON rg.GovernorID  = s.GovernorID
	LEFT JOIN #Healed      he  ON he.GovernorID  = s.GovernorID
	LEFT JOIN #Ranged      ran ON ran.GovernorID = s.GovernorID   
	WHERE s.GovernorID IS NOT NULL;


    -- Cleanup temps from stage step
    DROP TABLE IF EXISTS #Deads, #Kills, #KillsT4, #KillsT5, #Helps, #RSSAssist, #RSSGathered, #Power, #Snapshot, #LATEST, #Healed, #Ranged, #KillPoints, #GovernorList;

    -----------------------------------------------
    -- 8. DKP + HoH (normalize DKP column name)
    -----------------------------------------------
    SELECT  S1.[GovernorID],
            CASE WHEN z.GovernorID = s1.GovernorID
                 THEN ROUND((S1.[T4&T5_KILLSDelta]*3 + (S1.[DeadsDelta] * 0.1) * 8), 0)
                 ELSE ROUND((S1.[T4&T5_KILLSDelta]*3 +  S1.[DeadsDelta]      * 8), 0)
            END AS [DKP_SCORE]
    INTO #DKP
    FROM dbo.STAGING_STATS AS S1
    LEFT JOIN dbo.ZEROED    AS Z ON Z.GovernorID = S1.GovernorID AND Z.ScanOrder = @Scan;

    SELECT GovernorID, MAX(T4_Deads) AS [T4 Deads], MAX(T5_Deads) AS [T5 Deads], MAX(KVK_START_SCANORDER) AS SCANORDER 
    INTO #HD1
    FROM dbo.HoH_Deads 
    GROUP BY GovernorID;

    -----------------------------------------------
    -- 9. Dynamic final table (typed columns!)
    -----------------------------------------------
    DECLARE @ExcelTbl       sysname       = N''EXCEL_FOR_KVK_'' + CAST(@KVK AS nvarchar(10));
    DECLARE @TargetsTbl     sysname       = N''TARGETS_''       + CAST(@KVK AS nvarchar(10));
    DECLARE @ExcelTblFull   nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@ExcelTbl);
    DECLARE @TargetsTblFull nvarchar(260) = QUOTENAME(''dbo'') + N''.'' + QUOTENAME(@TargetsTbl);

    DECLARE @sql nvarchar(max) = N'''';

    SET @sql += N''DROP TABLE IF EXISTS '' + @ExcelTblFull + N'';'' + CHAR(10);

    SET @sql += N''
    SELECT TOP (5000)
        S.[PowerRank]                                                AS [Rank],
        CAST(ROW_NUMBER() OVER (ORDER BY D.[DKP_SCORE] DESC) AS int) AS [KVK_RANK],
        S.[GovernorID]                                               AS [Gov_ID],
        CAST(COALESCE(NM.GovernorName,S.[GovernorName]) AS nvarchar(255)) AS [Governor_Name],

        CAST(S.[Power] AS bigint)                                    AS [Starting Power],
        CAST(S.Power_Delta AS bigint)                                AS [Power_Delta],

        CAST(S.[Civilization] AS nvarchar(100))                      AS [Civilization],
        CAST(S.[KvKPlayed] AS int)                                   AS [KvKPlayed],
        CAST(S.[MostKvKKill] AS bigint)                              AS [MostKvKKill],
        CAST(S.[MostKvKDead] AS bigint)                              AS [MostKvKDead],
        CAST(S.[MostKvKHeal] AS bigint)                              AS [MostKvKHeal],
        CAST(S.[Acclaim] AS bigint)                                  AS [Acclaim],
        CAST(S.[HighestAcclaim] AS bigint)                           AS [HighestAcclaim],
        CAST(S.[AOOJoined] AS bigint)                                AS [AOOJoined],
        CAST(S.[AOOWon] AS int)                                      AS [AOOWon],
        CAST(S.[AOOAvgKill] AS bigint)                               AS [AOOAvgKill],
        CAST(S.[AOOAvgDead] AS bigint)                               AS [AOOAvgDead],
        CAST(S.[AOOAvgHeal] AS bigint)                               AS [AOOAvgHeal],
        CAST(S.[Conduct] AS decimal(5,2))                             AS [Conduct],

        CAST(S.[Starting_T4&T5_KILLS] AS bigint)                     AS [Starting_T4&T5_KILLS],
        CAST(S.[T4KillsDelta] AS bigint)                             AS [T4_KILLS],
        CAST(S.[T5KillsDelta] AS bigint)                             AS [T5_KILLS],
        CAST(S.[T4&T5_KILLSDelta] AS bigint)                         AS [T4&T5_Kills],
        CAST(S.KILLS_OUTSIDE_KVK AS bigint)                          AS [KILLS_OUTSIDE_KVK],

        CAST(T.[Kill_Target] AS bigint)                                 AS [Kill Target],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE ROUND( (CAST(S.[T4&T5_KILLSDelta] AS decimal(19,2)) / CAST(T.[Kill_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Kill Target],

        CAST(S.[Starting_Deads] AS bigint)                           AS [Starting_Deads],
        CAST(S.[DeadsDelta] AS bigint)                               AS [Deads_Delta],
        CAST(S.DEADS_OUTSIDE_KVK AS bigint)                          AS [DEADS_OUTSIDE_KVK],

        CAST(COALESCE(HD.[T4 Deads], 0) AS bigint)                   AS [T4_Deads],
        CAST(COALESCE(HD.[T5 Deads], 0) AS bigint)                   AS [T5_Deads],

        CAST(T.[Dead_Target] AS bigint)                                 AS [Dead_Target],
        CAST(
            CASE
                WHEN T.[Dead_Target] = 0 THEN 0
                WHEN Z.GovernorID = S.GovernorID
                    THEN ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) * 0.1 / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
                ELSE ROUND( (CAST(S.DeadsDelta AS decimal(19,2)) / CAST(T.[Dead_Target] AS decimal(19,2))) * 100, 2)
            END
            AS decimal(9,2)
        )                                                            AS [% of Dead Target],

        CAST(Z.Zeroed AS bit)                                        AS [Zeroed],

        CAST(D.[DKP_SCORE] AS bigint)                                AS [DKP_SCORE],
        CAST(
            CASE WHEN T.[Kill_Target] = 0 THEN 0
                 ELSE (CAST(T.Kill_Target AS bigint) * 3 + CAST(T.Dead_Target AS bigint) * 8)
            END
            AS bigint
        )                                                            AS [DKP Target],

        CAST(
            CASE
                WHEN (CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) = 0 THEN 0
                ELSE ROUND(
                    (CAST(D.[DKP_SCORE] AS decimal(19,2)) /
                     CAST((CAST(T.[Kill_Target] AS bigint) * 3 + CAST(T.[Dead_Target] AS bigint) * 8) AS decimal(19,2))) * 100,
                    2
                )
            END
            AS decimal(9,2)
        )                                                            AS [% of DKP Target],

        CAST(S.[HelpsDelta] AS bigint)                               AS [HelpsDelta],
        CAST(S.[RSSASSISTDelta] AS bigint)                           AS [RSS_Assist_Delta],
        CAST(S.[RSSGatheredDelta] AS bigint)                         AS [RSS_Gathered_Delta],

        CAST(S.[P4T4&T5_KillsDelta] AS bigint)                       AS [Pass 4 Kills],
        CAST(S.[P6T4&T5_KillsDelta] AS bigint)                       AS [Pass 6 Kills],
        CAST(S.[P7T4&T5_KillsDelta] AS bigint)                       AS [Pass 7 Kills],
        CAST(S.[P8T4&T5_KillsDelta] AS bigint)                       AS [Pass 8 Kills],

        CAST(S.P4DeadsDelta AS bigint)                               AS [Pass 4 Deads],
        CAST(S.P6DeadsDelta AS bigint)                               AS [Pass 6 Deads],
        CAST(S.P7DeadsDelta AS bigint)                               AS [Pass 7 Deads],
        CAST(S.P8DeadsDelta AS bigint)                               AS [Pass 8 Deads],

        CAST(S.[HealedTroops] AS bigint)                             AS [Starting_HealedTroops],
        CAST(S.[HealedTroopsDelta] AS bigint)                        AS [HealedTroopsDelta],

        CAST(S.[KillPoints] AS bigint)                               AS [Starting_KillPoints],
        CAST(S.[KillPointsDelta] AS bigint)                          AS [KillPointsDelta],

        CAST(S.[RangedPoints] AS bigint)                             AS [RangedPoints],
        CAST(S.[RangedPointsDelta] AS bigint)                        AS [RangedPointsDelta],

        CAST(S.[AutarchTimes] AS bigint)                             AS [AutarchTimes],

        CAST(S.[MaxPreKvkPoints] AS bigint)                          AS [Max_PreKvk_Points],
        CAST(S.[MaxHonorPoints] AS bigint)                           AS [Max_HonorPoints],
        CAST(S.[PreKvkRank] AS bigint)                               AS [PreKvk_Rank],
        CAST(S.[HonorRank] AS bigint)                                AS [Honor_Rank],

        CAST(@pKVK AS int)                                           AS [KVK_NO]
    INTO '' + @ExcelTblFull + N''
    FROM dbo.STAGING_STATS AS S
    LEFT JOIN dbo.v_ReportGovernorNames NM ON NM.GovernorID=S.GovernorID
    LEFT JOIN #HD1  AS HD ON S.GovernorID = HD.GovernorID
    LEFT JOIN '' + @TargetsTblFull + N'' AS T ON T.GovernorID = S.GovernorID
    LEFT JOIN #DKP  AS D  ON D.GovernorID = S.GovernorID
    LEFT JOIN dbo.ZEROED AS Z ON Z.GovernorID = S.GovernorID AND Z.ScanOrder = @pScan
    ORDER BY S.PowerRank ASC;'';

	IF CHARINDEX(N''COALESCE(HD.[T4 Deads]'', @sql) = 0
	BEGIN
		RAISERROR(''HD reference missing from SQL string (string likely broken).'',16,1);
	END

    EXEC sp_executesql
        @sql,
        N''@pScan int, @pKVK int'',
        @pScan = @Scan,
        @pKVK  = @KVK;

	-- Call index creation procedure with BOTH parameters
	EXEC dbo.sp_Create_Excel_For_Kvk_Indexes @FullTableName = @ExcelTblFull, @TableBase = @ExcelTbl;

	-- ✅ NEW: Update statistics for optimal query performance
    DECLARE @UpdateStatsSQL NVARCHAR(MAX) = N''UPDATE STATISTICS '' + @ExcelTblFull + N'' WITH FULLSCAN;'';
    EXEC sp_executesql @UpdateStatsSQL;
    PRINT ''Updated statistics on '' + @ExcelTblFull + '' with FULLSCAN'';

    DROP TABLE IF EXISTS #DKP, #HD1;

    EXEC dbo.sp_Refresh_View_EXCEL_FOR_KVK_All;
    EXEC dbo.usp_RecordKvkFinalReportCompletion
        @KVKNo = @KVK,
        @FinalScanOrder = @LatestScanToUse,
        @FinalizationBasis = N''LIVE_OUTPUT'';

	        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH

    PRINT ''Completed KVK '' + CAST(@KVK AS varchar(10))
        + '' with ScanOrder='' + CAST(@Scan AS varchar(20))
        + '', LatestScanUsed='' + CAST(@LatestScanToUse AS varchar(20))
        + '' at '' + CONVERT(varchar, GETDATE(), 120);
END';
-- dbo.CREATE_DASH
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE [dbo].[CREATE_DASH]
WITH EXECUTE AS CALLER
AS
BEGIN

-- Clear target table
TRUNCATE TABLE DASH;

-- Step 1: Create #RankingGroups temp table
IF OBJECT_ID(''tempdb..#RankingGroups'') IS NOT NULL DROP TABLE #RankingGroups;

SELECT DISTINCT KVK_NO, RankGroup, KVK_Rank_Max
INTO #RankingGroups
FROM (
    SELECT KVK_NO, ''50'' AS RankGroup, 50 AS KVK_Rank_Max FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, ''100'', 100 FROM EXCEL_FOR_DASHBOARD
    UNION ALL
    SELECT KVK_NO, ''150'', 150 FROM EXCEL_FOR_DASHBOARD
) AS t;

-- Step 2: Create #Aggregated temp table
IF OBJECT_ID(''tempdb..#Aggregated'') IS NOT NULL DROP TABLE #Aggregated;

SELECT
    rg.RankGroup AS [RANK],
    rg.RankGroup AS [KVK_RANK],
    CASE rg.RankGroup
        WHEN ''50'' THEN ''999999997''
        WHEN ''100'' THEN ''999999998''
        WHEN ''150'' THEN ''999999999''
    END AS [Gov_ID],
    CASE rg.RankGroup
        WHEN ''50'' THEN ''Top50''
        WHEN ''100'' THEN ''Top100''
        WHEN ''150'' THEN ''Kingdom Average''
    END AS [Governor_Name],
    ROUND(AVG([Starting POWER]), 0) AS [Starting Power],
    ROUND(AVG([T4_Kills]), 0) AS [T4_Kills],
    ROUND(AVG([T5_Kills]), 0) AS [T5_Kills],
    ROUND(AVG([T4&T5_Kills]), 0) AS [T4&T5_Kills],
    ROUND(AVG([Kill Target]), 0) AS [Kill Target],
    ROUND(AVG([% of Kill target]), 0) AS [% of Kill target],
    ROUND(AVG([Deads_Delta]), 0) AS [Deads],
    ROUND(AVG([T4_Deads]), 0) AS [T4_Deads],
    ROUND(AVG([T5_Deads]), 0) AS [T5_Deads],
    ROUND(AVG([Dead_Target]), 0) AS [Dead_Target],
    ROUND(AVG([% of Dead Target]), 0) AS [% of Dead_Target],
    ed.KVK_NO,
    ROUND(AVG([Pass 4 Kills]), 0) AS [Pass 4 Kills],
    ROUND(AVG([Pass 6 Kills]), 0) AS [Pass 6 Kills],
    ROUND(AVG([Pass 7 Kills]), 0) AS [Pass 7 Kills],
    ROUND(AVG([Pass 8 Kills]), 0) AS [Pass 8 Kills],
    ROUND(AVG([POWER_DELTA]), 0) AS [POWER_DELTA],
    ROUND(AVG([DKP_Score]), 0) AS [DKP_Score],
    ROUND(AVG([DKP Target]), 0) AS [DKP Target],
    ROUND(AVG([% of DKP Target]), 0) AS [% of DKP Target]
INTO #Aggregated
FROM #RankingGroups rg
JOIN EXCEL_FOR_DASHBOARD ed
    ON ed.KVK_NO = rg.KVK_NO
   AND ed.KVK_RANK BETWEEN 1 AND rg.KVK_Rank_Max
GROUP BY rg.RankGroup, ed.KVK_NO;

-- Step 3: Insert into DASH
INSERT INTO DASH (
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [T4_Kills], [T5_Kills], [T4&T5_Kills],
    [Kill Target], [% of Kill target], [Deads], [T4_Deads],
    [T5_Deads], [Dead_Target], [% of Dead_Target], [KVK_NO],
    [Pass 4 Kills], [Pass 6 Kills], [Pass 7 Kills], [Pass 8 Kills],
    [POWER_DELTA], [DKP_Score], [DKP Target], [% of DKP Target]
)
SELECT *
FROM #Aggregated;

-- Step 4: Insert into EXCEL_FOR_DASHBOARD from DASH
INSERT INTO EXCEL_FOR_DASHBOARD (
    [Rank], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [Power_Delta], [T4_KILLS], [T5_KILLS],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads_Delta], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
)
SELECT 
    [RANK], [KVK_RANK], [Gov_ID], [Governor_Name],
    [Starting Power], [POWER_DELTA], [T4_Kills], [T5_Kills],
    [T4&T5_Kills], [Kill Target], [% of Kill target],
    [Deads], [T4_Deads], [T5_Deads], [Dead_Target],
    [% of Dead_Target], [DKP_Score], [DKP Target],
    [% of DKP Target], [Pass 4 Kills], [Pass 6 Kills],
    [Pass 7 Kills], [Pass 8 Kills], [KVK_NO]
FROM DASH;

EXEC dbo.usp_ApplyReportGovernorNames @Report=N''DASH'';
EXEC dbo.usp_ApplyReportGovernorNames @Report=N''EXCEL_FOR_DASHBOARD'';

-- Cleanup temp tables
DROP TABLE IF EXISTS #RankingGroups;
DROP TABLE IF EXISTS #Aggregated;

 END;';
IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 52980,'Phase 1 release transaction escaped.',1;
