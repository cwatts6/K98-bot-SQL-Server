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
    -- The nullable legacy path is private and reached only by UPDATE_ALL2's
    -- same-owner static call. Recovery callers must present durable authority.
    IF @ExportPreparationID IS NULL
        THROW 51961, 'Recovery reporting requires a preparation ID.', 1;
    EXEC dbo.usp_S11CompleteStatsReportsCore
        @CompletedFileName=@CompletedFileName,
        @ExportPreparationID=@ExportPreparationID,
        @actual_param1=@actual_param1, @actual_param2=@actual_param2,
        @rowsKS5=@rowsKS5, @rowsKS4=@rowsKS4, @StartTime=@StartTime;
END;
