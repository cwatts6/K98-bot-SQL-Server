SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UPDATE_RALLY_DATA]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UPDATE_RALLY_DATA] AS' 
END
ALTER PROCEDURE [dbo].[UPDATE_RALLY_DATA]
WITH EXECUTE AS CALLER
AS
BEGIN
    THROW 52940, 'dbo.UPDATE_RALLY_DATA is retired by P02 D4; no work was performed. Use the supported import/report workflow.', 1;
END
