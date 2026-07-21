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
    DECLARE @HeaderPosition int = 1;
    DECLARE @ProcedureTokenPosition int;
    DECLARE @ModuleVerb nvarchar(6);
    DECLARE @CreateOrAlter bit = 0;

    WHILE @HeaderPosition <= LEN(@UpperUpdateDefinition)
          AND UNICODE(SUBSTRING(@UpperUpdateDefinition, @HeaderPosition, 1))
              IN (9, 10, 13, 32)
        SET @HeaderPosition += 1;

    IF @HeaderPosition NOT BETWEEN 1 AND 64
        THROW 51205, 'UPDATE_ALL2 module header starts outside the allowed prefix.', 1;

    IF SUBSTRING(@UpperUpdateDefinition, @HeaderPosition, LEN(N'CREATE')) = N'CREATE'
        SET @ModuleVerb = N'CREATE';
    ELSE IF SUBSTRING(@UpperUpdateDefinition, @HeaderPosition, LEN(N'ALTER')) = N'ALTER'
        SET @ModuleVerb = N'ALTER';
    ELSE
        THROW 51205, 'UPDATE_ALL2 module header is not CREATE or ALTER.', 1;

    SET @ProcedureTokenPosition = @HeaderPosition + LEN(@ModuleVerb);
    WHILE UNICODE(SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, 1))
              IN (9, 10, 13, 32)
        SET @ProcedureTokenPosition += 1;

    IF @ModuleVerb = N'CREATE'
       AND SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, LEN(N'OR')) = N'OR'
    BEGIN
        SET @CreateOrAlter = 1;
        SET @ProcedureTokenPosition += LEN(N'OR');
        WHILE UNICODE(SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, 1))
                  IN (9, 10, 13, 32)
            SET @ProcedureTokenPosition += 1;
        IF SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, LEN(N'ALTER'))
              <> N'ALTER'
            THROW 51205, 'UPDATE_ALL2 CREATE OR ALTER header is malformed.', 1;
        SET @ProcedureTokenPosition += LEN(N'ALTER');
        WHILE UNICODE(SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, 1))
                  IN (9, 10, 13, 32)
            SET @ProcedureTokenPosition += 1;
    END;

    IF SUBSTRING(@UpperUpdateDefinition, @ProcedureTokenPosition, LEN(N'PROC')) <> N'PROC'
        THROW 51205, 'UPDATE_ALL2 module header is not PROC or PROCEDURE.', 1;

    IF @ModuleVerb = N'CREATE' AND @CreateOrAlter = 0
        SET @UpdateDefinition = STUFF(
            @UpdateDefinition, @HeaderPosition, LEN(N'CREATE'), N'ALTER'
        );

    EXEC sys.sp_executesql @UpdateDefinition;
END;
GO
