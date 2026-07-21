/*
MigrationId: 20260719_007_wire_governor_name_history_post_scan
Purpose: Run the idempotent governor-alias observation upsert inside the durable scan-import phase
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A during deployment; future completed scan imports update observed aliases
PreValidationQuery: SELECT OBJECT_ID(N'dbo.UPDATE_ALL2', N'P') AS ScanProcedure, OBJECT_ID(N'dbo.usp_UpsertGovernorNameHistoryForScan', N'P') AS AliasProcedure;
PostValidationQuery: SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2')) AS UpdatedDefinition;
RelatedBotPR:
RelatedSQLPR:

Notes:
- The hook runs before the Phase A import commit, after KingdomScanData4 has received the scan.
- The upsert is recomputed from authoritative observations and is safe to rerun for a scan order.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @UpdateDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2', N'P'));
DECLARE @AliasMarker nvarchar(300) =
    N'        -- 4) Truncate staging (safe post-insert)';
DECLARE @AliasHook nvarchar(700) =
    N'        EXEC dbo.usp_UpsertGovernorNameHistoryForScan @ScanOrder = @MaxScanOrder5;'
    + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10) + @AliasMarker;

IF @UpdateDefinition IS NULL
    THROW 51203, 'UPDATE_ALL2 was not found for the alias-history hook deployment.', 1;

IF CHARINDEX(N'usp_UpsertGovernorNameHistoryForScan', @UpdateDefinition) = 0
BEGIN
    IF CHARINDEX(@AliasMarker, @UpdateDefinition) = 0
        THROW 51204, 'UPDATE_ALL2 alias-history hook marker was not found.', 1;
    SET @UpdateDefinition = REPLACE(@UpdateDefinition, @AliasMarker, @AliasHook);

    -- OBJECT_DEFINITION preserves the module's original CREATE/ALTER header.
    -- A CREATE header must be changed before replaying an existing procedure.
    DECLARE @UpperUpdateDefinition nvarchar(max) = UPPER(@UpdateDefinition);
    DECLARE @CreateProcedurePosition int =
        CHARINDEX(N'CREATE PROCEDURE', @UpperUpdateDefinition);
    DECLARE @CreateProcPosition int =
        CHARINDEX(N'CREATE PROC', @UpperUpdateDefinition);

    IF @CreateProcedurePosition BETWEEN 1 AND 64
        SET @UpdateDefinition = STUFF(
            @UpdateDefinition,
            @CreateProcedurePosition,
            LEN(N'CREATE PROCEDURE'),
            N'ALTER PROCEDURE'
        );
    ELSE IF @CreateProcPosition BETWEEN 1 AND 64
        SET @UpdateDefinition = STUFF(
            @UpdateDefinition, @CreateProcPosition, LEN(N'CREATE PROC'), N'ALTER PROC'
        );

    EXEC sys.sp_executesql @UpdateDefinition;
END;
GO
