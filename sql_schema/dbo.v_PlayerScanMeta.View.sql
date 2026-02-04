SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerScanMeta]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerScanMeta]  AS 
SELECT
    GovernorID,
	    FirstScanDate,
    LastScanDate,
    OfflineDaysOver30
FROM dbo.PlayerScanMeta;

'
