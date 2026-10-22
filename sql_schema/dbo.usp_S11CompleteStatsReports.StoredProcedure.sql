SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE OR ALTER PROCEDURE dbo.usp_S11CompleteStatsReports
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
        THROW 51961, 'Recovery reporting requires a preparation ID.', 1;
    IF @@TRANCOUNT<>0
        THROW 51961, 'Recovery reporting requires no caller-owned transaction.', 1;
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
            THROW 51961, 'The exact immutable archive did not verify.', 1;
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
END;
