-- Candidate fragment, not a deployable migration. Apply with the coordinated
-- source/permission contracts after drain; never beneath the predecessor Bot.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') IS NULL
    THROW 51972,'Reviewed application role is missing.',1;

-- Preserve legacy output/staging DDL rights. Only lifecycle-table operations
-- that can bypass DML triggers (TRUNCATE, SWITCH, trigger suppression) are denied.
DENY ALTER ON OBJECT::dbo.KVKFinalReportHeader TO ExportLegacyEntryReader;
DENY ALTER ON OBJECT::dbo.MaintenanceKvkWork TO ExportLegacyEntryReader;
DENY ALTER ON OBJECT::dbo.MaintenanceWork TO ExportLegacyEntryReader;

GRANT EXECUTE ON OBJECT::dbo.usp_P02BeginCatalogueMutation TO ExportLegacyEntryReader;
GRANT EXECUTE ON OBJECT::dbo.usp_P02EndCatalogueMutation TO ExportLegacyEntryReader;
GRANT EXECUTE ON OBJECT::dbo.usp_P02ReadObservationBoundary TO ExportLegacyEntryReader;
-- NEXT VALUE is reached through same-owner static modules, so it uses SQL
-- ownership chaining; no direct sequence-update permission is added.
