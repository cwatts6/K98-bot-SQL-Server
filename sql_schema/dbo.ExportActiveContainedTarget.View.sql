SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE VIEW dbo.ExportActiveContainedTarget
AS
 SELECT t.FileID,t.ContainmentID,t.CreatedUTC
 FROM dbo.ExportContainedTarget t
 WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportLegacyCloseout c WHERE c.ContainmentID=t.ContainmentID);
GO
