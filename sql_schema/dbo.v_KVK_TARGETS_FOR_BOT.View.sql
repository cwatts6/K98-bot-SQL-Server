SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER VIEW dbo.v_KVK_TARGETS_FOR_BOT
AS
SELECT
    p.PublicationId,
    p.KVK_NO,
    p.PublicationState,
    p.SourceScanOrder,
    p.SourceScanType,
    p.ConfiguredDraftScan,
    p.ConfiguredMatchmakingScan,
    p.PublishedAtUtc,
    p.TargetRowCount,
    p.OutputObjectName,
    p.PublicationVersion,
    p.PublicationSignature,
    r.TargetRank,
    r.GovernorID,
    r.GovernorName,
    r.Power,
    r.KillTarget AS Kill_Target,
    r.MinimumKillTarget AS Min_Kill_Target,
    r.DeadTarget AS Deads_Target,
    r.DKPTarget AS DKP_Target
FROM dbo.KVK_Target_Publication AS p
JOIN dbo.KVK_Target_Publication_Row AS r
  ON r.PublicationId = p.PublicationId
WHERE p.IsCurrent = 1;
GO
