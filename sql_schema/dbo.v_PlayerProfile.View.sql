SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_PlayerProfile]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_PlayerProfile]  AS 
SELECT
    s.GovernorID,
    s.Governor_Name,
    s.Alliance,
    s.CityHallLevel,
    s.Power,
    s.Kills,
    s.Deads,
    s.RSS_Gathered,
    s.Helps,
    loc.X,
    loc.Y,
    loc.LastUpdated AS LocationUpdated,
    acc.Status,
    acc.UpdatedAt   AS StatusUpdated,
    f.FortsRank,
    f.FortsStarted,
    f.FortsJoined,
    f.FortsTotal,
    f.SnapshotAt    AS FortsUpdated,
    -- NEW:
    s.PowerRank
FROM dbo.v_PlayerLatestStats AS s
LEFT JOIN dbo.PlayerLocation            AS loc ON loc.GovernorID = s.GovernorID
LEFT JOIN dbo.PlayerAccountStatus       AS acc ON acc.GovernorID = s.GovernorID
LEFT JOIN dbo.v_PlayerFortsLatestWithRank AS f ON f.GovernorID = s.GovernorID;


'
