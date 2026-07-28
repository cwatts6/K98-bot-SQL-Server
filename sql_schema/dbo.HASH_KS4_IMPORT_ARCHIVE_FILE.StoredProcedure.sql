SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE] AS'
END
ALTER PROCEDURE [dbo].[HASH_KS4_IMPORT_ARCHIVE_FILE]
    @ApprovedPath [nvarchar](4000),
    @FileDigest [binary](32) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ClaimedRoot nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Claimed\';
    DECLARE @ArchiveRoot nvarchar(4000) =
        N'C:\discord_file_downloader\downloads\Import_Archive\';
    DECLARE @CompletedFileName nvarchar(260);

    IF LEFT(@ApprovedPath, LEN(@ClaimedRoot)) = @ClaimedRoot
        SET @CompletedFileName = SUBSTRING(@ApprovedPath, LEN(@ClaimedRoot) + 1, 260);
    ELSE IF LEFT(@ApprovedPath, LEN(@ArchiveRoot)) = @ArchiveRoot
        SET @CompletedFileName = SUBSTRING(@ApprovedPath, LEN(@ArchiveRoot) + 1, 260);

    IF @CompletedFileName IS NULL
       OR DATALENGTH(@CompletedFileName) <> 96
       OR LEFT(@CompletedFileName, 6) <> N'stats_'
       OR RIGHT(@CompletedFileName, 10) <> N'.ready.csv'
       OR SUBSTRING(@CompletedFileName, 7, 32)
            COLLATE Latin1_General_100_BIN2 LIKE N'%[^0-9a-f]%'
       OR @ApprovedPath NOT IN
          (
              @ClaimedRoot + @CompletedFileName,
              @ArchiveRoot + @CompletedFileName
          )
        THROW 51872, 'HASH_KS4_IMPORT_ARCHIVE_FILE refused an unexpected file path.', 1;

    DECLARE @HashCommand nvarchar(4000) =
        N'CMD /D /C certutil -hashfile "'
        + @ApprovedPath
        + N'" SHA256';
    DECLARE @HashExitCode int;
    DECLARE @HashHex varchar(64);
    DECLARE @HashOutput table
    (
        OutputLine nvarchar(255) NULL
    );

    SET @FileDigest = NULL;

    INSERT @HashOutput (OutputLine)
    EXEC @HashExitCode = master.dbo.xp_cmdshell @HashCommand;

    SELECT TOP (1)
        @HashHex =
            CONVERT(varchar(64), REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N''))
    FROM @HashOutput
    WHERE LEN(REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N'')) = 64
      AND REPLACE(LTRIM(RTRIM(OutputLine)), N' ', N'')
            NOT LIKE N'%[^0-9A-Fa-f]%';

    IF ISNULL(@HashExitCode, 1) = 0 AND @HashHex IS NOT NULL
        SET @FileDigest =
            TRY_CONVERT(binary(32), CONVERT(varchar(66), '0x' + @HashHex), 1);

    IF @FileDigest IS NULL
        THROW 51873, 'HASH_KS4_IMPORT_ARCHIVE_FILE could not calculate the approved file digest.', 1;
END
