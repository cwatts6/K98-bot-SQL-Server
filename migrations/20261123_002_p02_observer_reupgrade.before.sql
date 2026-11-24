DECLARE @id int,@body nvarchar(max);

SET @id=OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'e9f44eaaadb6e39281cc57a3b3ace57d9352d2cf1e879dfadcbcb6411fe23989'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.sp_ExcelOutput_ByKVK.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.sp_ExcelOutput_ByKVK.',1;

SET @id=OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'81388942e3808f7d4d520ee72b785460157b1f820d14e8090e9ac3d3542eba27'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_P02BeginCatalogueMutation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_P02BeginCatalogueMutation.',1;

SET @id=OBJECT_ID(N'dbo.usp_P02EndCatalogueMutation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'313b3d2e401658ef442f87710a72b3e0e2f29e7df3ca0d9cb86ecdd174ad5a9e'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_P02EndCatalogueMutation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_P02EndCatalogueMutation.',1;

SET @id=OBJECT_ID(N'dbo.usp_P02ReadObservationBoundary');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'4d2ecd3ad1a934b31e209024d70e0a3f4ab26e1970201509d85c60fcd36487ea'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_P02ReadObservationBoundary.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_P02ReadObservationBoundary.',1;

SET @id=OBJECT_ID(N'dbo.usp_RunMaintenance');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'876ee095581d60d7ae3e3e08a842e51a0a114011a00d868eaa4fbe6c1acadc33'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_RunMaintenance.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_RunMaintenance.',1;

SET @id=OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'f6ee927d6ce2e9b8cad78b50281eb81dea0a005e3401a2c3347603377c3c9a80'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_S11ValidateStatsReportStage.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_S11ValidateStatsReportStage.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sequences s JOIN sys.schemas sc ON sc.schema_id=s.schema_id
 WHERE sc.name=N'dbo' AND s.name=N'P02ObservationGeneration' AND TYPE_NAME(s.user_type_id)=N'bigint'
 AND s.user_type_id=s.system_type_id AND CONVERT(bigint,s.start_value)=1 AND CONVERT(bigint,s.increment)=1
 AND CONVERT(bigint,s.minimum_value)=1 AND CONVERT(bigint,s.maximum_value)=9223372036854775807
 AND s.is_cycling=0 AND s.is_cached=0 AND s.cache_size IS NULL AND s.is_exhausted=0
 AND CONVERT(bigint,s.current_value)>=1 AND CONVERT(bigint,s.current_value)<9223372036854775807
 AND s.create_date=s.modify_date AND USER_NAME(COALESCE(s.principal_id,sc.principal_id))=N'dbo')
 THROW 51973,'Observer sequence structure/state differs.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02HeaderObservation')
 THROW 51977,'Observer hook remains in returned state.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02KvkWorkObservation')
 THROW 51977,'Observer hook remains in returned state.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02MaintenanceObservation')
 THROW 51977,'Observer hook remains in returned state.',1;

IF EXISTS(SELECT 1 FROM sys.triggers WHERE name=N'tr_P02CatalogueObservation')
 THROW 51977,'Observer hook remains in returned state.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader'))
 THROW 51977,'Returned observer helper still has explicit role rights.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02EndCatalogueMutation') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader'))
 THROW 51977,'Returned observer helper still has explicit role rights.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02ReadObservationBoundary') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader'))
 THROW 51977,'Returned observer helper still has explicit role rights.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.KVKFinalReportHeader') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER')
 THROW 51977,'Returned lifecycle permission differs from predecessor.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceKvkWork') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER')
 THROW 51977,'Returned lifecycle permission differs from predecessor.',1;

IF EXISTS(SELECT 1 FROM sys.database_permissions WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceWork') AND minor_id=0 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') AND permission_name='ALTER')
 THROW 51977,'Returned lifecycle permission differs from predecessor.',1;

IF LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK'))),2))<>'97b4bc47a73277d20049558d33fdc623c84bc8f3a16779128d049d9fad29f918'
 THROW 51977,'Exact historical procedure bytes were not restored.',1;

IF LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_RunMaintenance'))),2))<>'eb05004d539c1ae5fbb4d83685c6916dc7fefd29428788e5238ea75202327138'
 THROW 51977,'Exact historical procedure bytes were not restored.',1;

IF LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_S11ValidateStatsReportStage'))),2))<>'8a0b6f7cdad350a08408e40c384771bff43e6a879ca9cc32aa967983e28af18d'
 THROW 51977,'Exact historical procedure bytes were not restored.',1;
