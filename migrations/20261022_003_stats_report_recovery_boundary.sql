/*
MigrationId: 20261022_003_stats_report_recovery_boundary
Purpose: Guard archive verification behind the permitted reporting entry point
Author: cwatts
CreatedUtc: 2026-10-22
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
Safety: No business invocation, receipt rewrite or permission expansion.
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact reviewed module preimage and idle protected authority
PostValidationQuery: Exact paired source contract and denied direct archive access
*/
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51961,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int,@Object int,@Body nvarchar(max);
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'Schema busy.',1;
IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH (HOLDLOCK) WHERE State<>'closed')
 THROW 51961,'Authority sessions must be closed.',1;
EXEC @Lock=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'SQL snapshot producer is live.',1;

SET @Object=OBJECT_ID(N'dbo.usp_S11CompleteStatsReports');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    OR @Object IS NULL
 THROW 51961,'Missing or incompatible usp_S11CompleteStatsReports definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN (0x78fd1381a630d4ec23fce8a1c4381642956a32d7b7145d74e457f63d8a6d3fd7,0xc4db4108be182c6a083e6a2d8416303c4b92cc634127b24b2b6d7d3ba1d3c471)
 THROW 51961,'Unreviewed usp_S11CompleteStatsReports preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected usp_S11CompleteStatsReports execution context or signature.',1;
EXEC sys.sp_executesql N'CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReports
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
    IF @ExportPreparationID IS NULL
        THROW 51961, ''Recovery reporting requires a preparation ID.'', 1;
    IF @@TRANCOUNT<>0
        THROW 51961, ''Recovery reporting requires no caller-owned transaction.'', 1;
    BEGIN TRY
        -- Validate exact committed input, configuration and both session guards
        -- before reaching the private archive module through ownership chaining.
        BEGIN TRANSACTION;
        EXEC dbo.usp_S11ValidateStatsReportStage
            @PreparationID=@ExportPreparationID,@CompletedFileName=@CompletedFileName;
        COMMIT TRANSACTION;
        DECLARE @ArchiveReturnCode int;
        EXEC @ArchiveReturnCode=dbo.ARCHIVE_IMPORT_STAGING_FILE
            @CompletedFileName=@CompletedFileName;
        IF @ArchiveReturnCode<>0
            THROW 51961, ''The exact immutable archive did not verify.'', 1;
        -- The core revalidates each reporting transaction and skips receipts
        -- already committed. Neither entry point invokes the import pipeline.
        EXEC dbo.usp_S11CompleteStatsReportsCore
            @CompletedFileName=@CompletedFileName,
            @ExportPreparationID=@ExportPreparationID,
            @actual_param1=@actual_param1, @actual_param2=@actual_param2,
            @rowsKS5=@rowsKS5, @rowsKS4=@rowsKS4, @StartTime=@StartTime;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK;
        THROW;
    END CATCH;
END;';

COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
