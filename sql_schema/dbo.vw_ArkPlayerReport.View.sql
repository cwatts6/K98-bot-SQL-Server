SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[vw_ArkPlayerReport]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[vw_ArkPlayerReport]  AS 
WITH base AS (
    SELECT
        s.GovernorId,
        MAX(s.GovernorNameSnapshot) AS GovernorName
    FROM dbo.ArkSignups s
    GROUP BY s.GovernorId
),
matches_played AS (
    SELECT
        s.GovernorId,
        COUNT(DISTINCT s.MatchId) AS MatchesPlayed
    FROM dbo.ArkSignups s
    JOIN dbo.ArkMatches m ON m.MatchId = s.MatchId
    WHERE s.Status = ''Active''
      AND ISNULL(s.NoShow, 0) = 0
      AND m.Status = ''Completed''
    GROUP BY s.GovernorId
),
wins_losses AS (
    SELECT
        s.GovernorId,
        SUM(CASE WHEN m.Result = ''Win'' THEN 1 ELSE 0 END) AS Wins,
        SUM(CASE WHEN m.Result = ''Loss'' THEN 1 ELSE 0 END) AS Losses
    FROM dbo.ArkSignups s
    JOIN dbo.ArkMatches m ON m.MatchId = s.MatchId
    WHERE s.Status = ''Active''
      AND ISNULL(s.NoShow, 0) = 0
      AND m.Status = ''Completed''
      AND m.Result IS NOT NULL
    GROUP BY s.GovernorId
),
emergency_withdraws AS (
    SELECT
        GovernorId,
        COUNT(*) AS EmergencyWithdraws
    FROM dbo.ArkAuditLog
    WHERE ActionType = ''emergency_withdraw''
      AND GovernorId IS NOT NULL
    GROUP BY GovernorId
),
no_shows AS (
    SELECT
        GovernorId,
        COUNT(*) AS NoShows
    FROM dbo.ArkSignups
    WHERE ISNULL(NoShow, 0) = 1
    GROUP BY GovernorId
)
SELECT
    b.GovernorId,
    b.GovernorName,
    ISNULL(mp.MatchesPlayed, 0) AS MatchesPlayed,
    ISNULL(ns.NoShows, 0) AS NoShows,
    ISNULL(ew.EmergencyWithdraws, 0) AS EmergencyWithdraws,
    ISNULL(wl.Wins, 0) AS Wins,
    ISNULL(wl.Losses, 0) AS Losses,
    CASE
        WHEN ISNULL(wl.Wins, 0) + ISNULL(wl.Losses, 0) = 0 THEN 0
        ELSE CAST(ISNULL(wl.Wins, 0) AS float)
             / NULLIF(ISNULL(wl.Wins, 0) + ISNULL(wl.Losses, 0), 0)
    END AS WinPct
FROM base b
LEFT JOIN matches_played mp ON mp.GovernorId = b.GovernorId
LEFT JOIN wins_losses wl ON wl.GovernorId = b.GovernorId
LEFT JOIN emergency_withdraws ew ON ew.GovernorId = b.GovernorId
LEFT JOIN no_shows ns ON ns.GovernorId = b.GovernorId;

'
