SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TEST]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[TEST] AS' 
END
ALTER PROCEDURE [dbo].[TEST]
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, 'dbo.TEST is retired by P02 D4; no work was performed. Use the supported import/report workflow.', 1;
END
