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

    IF @ApprovedPath IS NULL
       OR
       (
           @ApprovedPath <> N'C:\discord_file_downloader\downloads\stats.csv'
           AND @ApprovedPath NOT LIKE N'C:\discord_file_downloader\downloads\Import[_]Archive\Stats[_]%'
       )
       OR CHARINDEX(N'''', @ApprovedPath) > 0
       OR CHARINDEX(NCHAR(10), @ApprovedPath) > 0
       OR CHARINDEX(NCHAR(13), @ApprovedPath) > 0
       OR CHARINDEX(N'&', @ApprovedPath) > 0
       OR CHARINDEX(N'|', @ApprovedPath) > 0
       OR CHARINDEX(N'<', @ApprovedPath) > 0
       OR CHARINDEX(N'>', @ApprovedPath) > 0
       OR CHARINDEX(N'^', @ApprovedPath) > 0
       OR CHARINDEX(N'%', @ApprovedPath) > 0
       OR CHARINDEX(N'!', @ApprovedPath) > 0
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
