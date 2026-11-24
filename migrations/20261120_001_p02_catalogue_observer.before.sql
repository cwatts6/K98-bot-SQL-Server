IF DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') IS NULL
 THROW 51973,'Reviewed application role is missing.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='97b4bc47a73277d20049558d33fdc623c84bc8f3a16779128d049d9fad29f918')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.sp_ExcelOutput_ByKVK.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.usp_RunMaintenance','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='eb05004d539c1ae5fbb4d83685c6916dc7fefd29428788e5238ea75202327138')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.usp_RunMaintenance.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
    JOIN sys.schemas s ON s.schema_id=o.schema_id
    WHERE o.object_id=OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage','P')
      AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
      AND m.execute_as_principal_id IS NULL
      AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo'
      AND LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2))='8a0b6f7cdad350a08408e40c384771bff43e6a879ca9cc32aa967983e28af18d')
    THROW 51973,'Reviewed observer predecessor body differs: dbo.usp_S11ValidateStatsReportStage.',1;

IF OBJECT_ID(N'dbo.P02ObservationGeneration') IS NOT NULL THROW 51973,'Observer object already exists: dbo.P02ObservationGeneration.',1;

IF OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02BeginCatalogueMutation.',1;

IF OBJECT_ID(N'dbo.usp_P02EndCatalogueMutation') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02EndCatalogueMutation.',1;

IF OBJECT_ID(N'dbo.usp_P02ReadObservationBoundary') IS NOT NULL THROW 51973,'Observer object already exists: dbo.usp_P02ReadObservationBoundary.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02CatalogueObservation') THROW 51973,'Observer trigger already exists: tr_P02CatalogueObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02HeaderObservation') THROW 51973,'Observer trigger already exists: tr_P02HeaderObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02KvkWorkObservation') THROW 51973,'Observer trigger already exists: tr_P02KvkWorkObservation.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02MaintenanceObservation') THROW 51973,'Observer trigger already exists: tr_P02MaintenanceObservation.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.KVKFinalReportHeader') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceKvkWork') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceWork') AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER') THROW 51973,'Lifecycle ALTER predecessor differs.',1;
