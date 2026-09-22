SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IMPORT_STAGING_PROC]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IMPORT_STAGING_PROC] AS' 
END
ALTER PROCEDURE [dbo].[IMPORT_STAGING_PROC]
	@CompletedFileName [nvarchar](260),
	@ImportFileDigest [binary](32) = NULL OUTPUT,
	@ArchivePath [nvarchar](4000) = NULL OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    IF @@TRANCOUNT <> 0
        THROW 51807, 'IMPORT_STAGING_PROC refuses caller-owned transactions; execute the public entry point with no active transaction.', 1;

    SET XACT_ABORT ON;

    DECLARE @ReturnCode int;
    DECLARE @ClaimedPath nvarchar(4000);
    DECLARE @ImportError nvarchar(2000);

    EXEC dbo.CLAIM_KS4_IMPORT_FILE
        @CompletedFileName = @CompletedFileName,
        @FileDigest = @ImportFileDigest OUTPUT,
        @ClaimedPath = @ClaimedPath OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT;

    EXEC @ReturnCode = dbo.IMPORT_STAGING_PROC_CORE
        @CompletedFileName = @CompletedFileName,
        @ImportFileDigest = @ImportFileDigest OUTPUT,
        @ArchivePath = @ArchivePath OUTPUT,
        @ImportError = @ImportError OUTPUT;

    RETURN @ReturnCode;
END
