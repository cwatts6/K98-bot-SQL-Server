SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
CREATE OR ALTER FUNCTION dbo.fn_NormalizeGovernorNameKey
(
    @GovernorName nvarchar(255)
)
RETURNS nvarchar(100)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @Normalized nvarchar(255);
    SET @Normalized = REPLACE(REPLACE(REPLACE(REPLACE(
        COALESCE(@GovernorName, N''), NCHAR(9), N' '), NCHAR(10), N' '),
        NCHAR(13), N' '), NCHAR(160), N' ');
    SET @Normalized = LTRIM(RTRIM(@Normalized));
    WHILE CHARINDEX(N'  ', @Normalized) > 0
        SET @Normalized = REPLACE(@Normalized, N'  ', N' ');
    SET @Normalized = LOWER(@Normalized);
    RETURN NULLIF(LEFT(@Normalized, 100), N'');
END
