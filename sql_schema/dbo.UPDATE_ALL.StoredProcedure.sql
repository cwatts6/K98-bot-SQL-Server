SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_ALL]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_ALL] AS' 
END
ALTER PROCEDURE [dbo].[UPDATE_ALL]
	@param1 [float] = NULL,
	@param2 [nvarchar](100) = NULL,
    @CompletedFileName [nvarchar](260)
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, 'dbo.UPDATE_ALL is retired by P02 D4; no work was performed. Use the supported import/report workflow.', 1;
END
