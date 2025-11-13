SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_EXCEL_FOR_KVK_Started]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_EXCEL_FOR_KVK_Started]  AS 
WITH MaxStarted AS (
        SELECT MAX(KVK_NO) AS MaxKVK
        FROM dbo.KVK_Details
        WHERE KVK_START_DATE IS NOT NULL
          AND KVK_START_DATE <= SYSUTCDATETIME()
    )
    SELECT a.*
    FROM dbo.v_EXCEL_FOR_KVK_All AS a
    CROSS JOIN MaxStarted ms
    WHERE a.[KVK_NO] <= ms.MaxKVK;

'
