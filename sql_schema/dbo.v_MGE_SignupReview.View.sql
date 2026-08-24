SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_MGE_SignupReview]'))
EXECUTE dbo.sp_executesql N'
CREATE VIEW [dbo].[v_MGE_SignupReview]  AS 
WITH latest_scan AS (
    SELECT k.*
    FROM dbo.KingdomScanData4 k
    WHERE k.SCANORDER = (SELECT MAX(SCANORDER) FROM dbo.KingdomScanData4)
),
excel_ranked AS (
    SELECT
        e.*,
        ROW_NUMBER() OVER (PARTITION BY e.Gov_ID ORDER BY e.KVK_NO DESC) AS rn
    FROM dbo.EXCEL_FOR_DASHBOARD e
),
kvk_latest AS (
    SELECT
        Gov_ID,
        KVK_RANK,
        [T4&T5_Kills],
        [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 1
),
kvk_prev AS (
    SELECT
        Gov_ID,
        KVK_RANK,
        [T4&T5_Kills],
        [% of Kill Target]
    FROM excel_ranked
    WHERE rn = 2
),
award_counts AS (
    SELECT
        s.SignupId,
        SUM(CASE WHEN a.AwardId IS NOT NULL THEN 1 ELSE 0 END) AS PriorAwardsOverallCount,
        SUM(
            CASE
                WHEN a.AwardId IS NOT NULL
                     AND a.RequestedCommanderId = s.RequestedCommanderId
                THEN 1 ELSE 0
            END
        ) AS PriorAwardsRequestedCommanderCount,
        SUM(
            CASE
                WHEN a.AwardId IS NOT NULL
                     AND a.CreatedUtc >= DATEADD(YEAR, -2, SYSUTCDATETIME())
                THEN 1 ELSE 0
            END
        ) AS PriorAwardsOverallLast2YearsCount
    FROM dbo.MGE_Signups s
    LEFT JOIN dbo.MGE_Awards a
        ON a.GovernorId = s.GovernorId
       AND a.EventId <> s.EventId
    GROUP BY s.SignupId
)
SELECT
    s.EventId,
    s.SignupId,
    s.GovernorId,
    s.GovernorNameSnapshot,
    s.RequestedCommanderId,
    s.RequestedCommanderName,
    s.RequestPriority,
    s.PreferredRankBand,
    s.CurrentHeads,
    s.KingdomRole,

    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS HasGearText,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS HasArmamentText,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NOT NULL
            THEN 1 ELSE 0
        END AS BIT
    ) AS HasGearOrArmamentText,

    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS HasGearAttachment,
    CAST(CASE WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NOT NULL THEN 1 ELSE 0 END AS BIT)
        AS HasArmamentAttachment,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NOT NULL
                 OR NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NOT NULL
            THEN 1 ELSE 0
        END AS BIT
    ) AS HasAnyAttachment,

    s.CreatedUtc AS SignupCreatedUtc,
    s.Source,

    ls.Power AS LatestPower,
    kvk_latest.KVK_RANK AS LatestKVKRank,
    kvk_prev.KVK_RANK AS LastKVKRank,
    kvk_latest.[T4&T5_Kills] AS LatestT4T5Kills,
    kvk_prev.[T4&T5_Kills] AS LastT4T5Kills,
    kvk_latest.[% of Kill Target] AS LatestPercentOfKillTarget,
    kvk_prev.[% of Kill Target] AS LastPercentOfKillTarget,

    ISNULL(ac.PriorAwardsRequestedCommanderCount, 0) AS PriorAwardsRequestedCommanderCount,
    ISNULL(ac.PriorAwardsOverallCount, 0) AS PriorAwardsOverallCount,
    ISNULL(ac.PriorAwardsOverallLast2YearsCount, 0) AS PriorAwardsOverallLast2YearsCount,

    CAST(
        CASE
            WHEN ISNULL(kvk_latest.KVK_RANK, 0) = 0
                 AND ISNULL(kvk_prev.KVK_RANK, 0) = 0
                 AND ISNULL(kvk_latest.[T4&T5_Kills], 0) = 0
                 AND ISNULL(kvk_prev.[T4&T5_Kills], 0) = 0
            THEN 1 ELSE 0
        END AS BIT
    ) AS WarningMissingKVKData,
    CAST(CASE WHEN s.CurrentHeads < 0 OR s.CurrentHeads > 680 THEN 1 ELSE 0 END AS BIT)
        AS WarningHeadsOutOfRange,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearAttachmentUrl, ''''))), '''') IS NULL
                 AND NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentAttachmentUrl, ''''))), '''') IS NULL
            THEN 1 ELSE 0
        END AS BIT
    ) AS WarningNoAttachments,
    CAST(
        CASE
            WHEN NULLIF(LTRIM(RTRIM(COALESCE(s.GearText, ''''))), '''') IS NULL
                 AND NULLIF(LTRIM(RTRIM(COALESCE(s.ArmamentText, ''''))), '''') IS NULL
            THEN 1 ELSE 0
        END AS BIT
    ) AS WarningNoGearOrArmamentText
FROM dbo.MGE_Signups s
JOIN dbo.MGE_Events e
    ON e.EventId = s.EventId
LEFT JOIN latest_scan ls
    ON CAST(ls.GovernorID AS BIGINT) = s.GovernorId
LEFT JOIN kvk_latest
    ON kvk_latest.Gov_ID = s.GovernorId
LEFT JOIN kvk_prev
    ON kvk_prev.Gov_ID = s.GovernorId
LEFT JOIN award_counts ac
    ON ac.SignupId = s.SignupId
WHERE s.IsActive = 1;


'
