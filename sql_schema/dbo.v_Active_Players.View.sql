SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_Active_Players]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_Active_Players]  AS 
SELECT
        KS4.[PowerRank],
        KS4.[GovernorName],
        CAST(KS4.[GovernorID] AS bigint) AS [GovernorID],  -- ✅ integer, no decimals
        KS4.[Alliance],
        KS4.[Power],
        KS4.[KillPoints],
        KS4.[Deads],
        KS4.[T1_Kills],
        KS4.[T2_Kills],
        KS4.[T3_Kills],
        KS4.[T4_Kills],
        KS4.[T5_Kills],
        KS4.[T4&T5_KILLS],
        KS4.[TOTAL_KILLS],
        KS4.[RSS_Gathered],
        KS4.[RSSAssistance],
        KS4.[Helps],
        KS4.[ScanDate],
        KS4.[Troops Power],
        KS4.[City Hall],
        KS4.[Tech Power],
        KS4.[Building Power],
        KS4.[Commander Power],
        CONCAT(PL.[X], '' : '', PL.[Y]) AS [LOCATION]
    FROM dbo.[KingdomScanData4] AS KS4
    LEFT JOIN dbo.[PlayerLocation] AS PL
        ON PL.[GovernorID] = KS4.[GovernorID]
    WHERE KS4.[SCANORDER] = (
        SELECT MAX([SCANORDER]) FROM dbo.[KingdomScanData4]
    );


'
