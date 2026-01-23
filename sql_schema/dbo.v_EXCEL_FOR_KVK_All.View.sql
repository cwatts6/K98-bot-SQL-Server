SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_EXCEL_FOR_KVK_All]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_EXCEL_FOR_KVK_All]  AS 
SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_3]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_4]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_5]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_6]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_7]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_8]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_9]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_10]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_11]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_12]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_13]
UNION ALL

SELECT
    [Rank],
    [KVK_RANK],
    [Gov_ID],
    [Governor_Name],
    [Starting Power],
    [Power_Delta],

   [Civilization] AS [Civilization],
    [KvKPlayed],
    [MostKvKKill],
    [MostKvKDead],
    [MostKvKHeal],
    [Acclaim],
    [HighestAcclaim],
    [AOOJoined],
    [AOOWon],
    [AOOAvgKill],
    [AOOAvgDead],
    [AOOAvgHeal],

    [Starting_T4&T5_KILLS],
    [T4_KILLS],
    [T5_KILLS],
    [T4&T5_Kills],
    [KILLS_OUTSIDE_KVK],
    [Kill Target],
    [% of Kill Target]        AS [% of Kill Target],

    [Starting_Deads]     AS [Starting_Deads],
    [Deads_Delta]     AS [Deads_Delta],
    [DEADS_OUTSIDE_KVK],
    [T4_Deads],
    [T5_Deads],
    [Dead_Target]     AS [Dead_Target],
    [% of Dead Target]  AS [% of Dead Target],

    [Zeroed],
    [DKP_SCORE]            AS [DKP_SCORE],
    [DKP Target],
    [% of DKP Target]         AS [% of DKP Target],

    [HelpsDelta]          AS [HelpsDelta],
    [RSS_Assist_Delta]      AS [RSS_Assist_Delta],
    [RSS_Gathered_Delta]    AS [RSS_Gathered_Delta],

    [Pass 4 Kills],
    [Pass 6 Kills],
    [Pass 7 Kills],
    [Pass 8 Kills],
    [Pass 4 Deads],
    [Pass 6 Deads],
    [Pass 7 Deads],
    [Pass 8 Deads],

    [Starting_HealedTroops]    AS [Starting_HealedTroops],
    [HealedTroopsDelta]    AS [HealedTroopsDelta],
    [Starting_KillPoints]      AS [Starting_KillPoints],
    [KillPointsDelta] AS [KillPointsDelta],

    [RangedPoints]         AS [RangedPoints],
    [RangedPointsDelta]    AS [RangedPointsDelta],

    [Max_PreKvk_Points]      AS [Max_PreKvk_Points],
    [Max_HonorPoints]       AS [Max_HonorPoints],
    [PreKvk_Rank]     AS [PreKvk_Rank],
    [Honor_Rank]      AS [Honor_Rank],

    [KVK_NO]
FROM dbo.[EXCEL_FOR_KVK_14]

'
