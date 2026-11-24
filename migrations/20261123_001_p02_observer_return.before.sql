DECLARE @id int,@body nvarchar(max);

SET @id=OBJECT_ID(N'dbo.sp_ExcelOutput_ByKVK');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE   PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE   PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'CREATE PROCEDURE %' THEN STUFF(@body,1,LEN(N'CREATE PROCEDURE'),N'PROCEDURE')
 WHEN @body LIKE N'ALTER PROCEDURE %' THEN STUFF(@body,1,LEN(N'ALTER PROCEDURE'),N'PROCEDURE')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'e8fcea60b5f9bfcc0b1931c73a1c15ddee63e7154ef9ad675d548d5fff3663dd'
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
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'21436b51acb3f88552e9fd3c375c6f09d4df7ec54bd0e16c5d4ab2e8fe42e75c'
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
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'31ba1ada30327ae732c1f70a6e8418c3526f22b94313a78b2b8794bb1bc6fa6f'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: dbo.usp_S11ValidateStatsReportStage.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='P' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: dbo.usp_S11ValidateStatsReportStage.',1;

SET @id=(SELECT object_id FROM sys.triggers WHERE parent_class=0 AND name=N'tr_P02CatalogueObservation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE   TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE   TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'ALTER TRIGGER'),N'TRIGGER')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'4f015698f5a9fb6297c8469f6b3f9c26a16207117ae3331afe16841f538161a5'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: tr_P02CatalogueObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=@id AND type='TR'
 AND parent_class=0 AND parent_id=0 AND is_disabled=0 AND is_not_for_replication=0
 AND is_instead_of_trigger=0)
 THROW 51973,'Observer trigger state differs: tr_P02CatalogueObservation.',1;

SET @id=OBJECT_ID(N'dbo.tr_P02HeaderObservation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE   TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE   TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'ALTER TRIGGER'),N'TRIGGER')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'5e13d5f159f7590259257a1683bc2ec42e50cc6841cd36b7aa29747cfce704a8'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: tr_P02HeaderObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=@id AND type='TR'
 AND parent_class=1 AND parent_id=OBJECT_ID(N'dbo.KVKFinalReportHeader') AND is_disabled=0 AND is_not_for_replication=0
 AND is_instead_of_trigger=0)
 THROW 51973,'Observer trigger state differs: tr_P02HeaderObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='TR' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: tr_P02HeaderObservation.',1;

SET @id=OBJECT_ID(N'dbo.tr_P02KvkWorkObservation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE   TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE   TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'ALTER TRIGGER'),N'TRIGGER')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'a270dc5b8c2bf21f8f7e766216f3340fad4a464d501770402bfd3d946d498da7'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: tr_P02KvkWorkObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=@id AND type='TR'
 AND parent_class=1 AND parent_id=OBJECT_ID(N'dbo.MaintenanceKvkWork') AND is_disabled=0 AND is_not_for_replication=0
 AND is_instead_of_trigger=0)
 THROW 51973,'Observer trigger state differs: tr_P02KvkWorkObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='TR' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: tr_P02KvkWorkObservation.',1;

SET @id=OBJECT_ID(N'dbo.tr_P02MaintenanceObservation');
SET @body=REPLACE(OBJECT_DEFINITION(@id),NCHAR(13)+NCHAR(10),NCHAR(10));
SET @body=CASE
 WHEN @body LIKE N'CREATE OR ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE OR ALTER TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE   TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE   TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'CREATE TRIGGER %' THEN STUFF(@body,1,LEN(N'CREATE TRIGGER'),N'TRIGGER')
 WHEN @body LIKE N'ALTER TRIGGER %' THEN STUFF(@body,1,LEN(N'ALTER TRIGGER'),N'TRIGGER')
 ELSE NULL END;
IF @id IS NULL OR @body IS NULL OR LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',@body),2))<>'6537b1c517c8638eb40f178122a2df22341b07c563b47c4f58267afc0f6b6404'
 OR NOT EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@id AND uses_ansi_nulls=1 AND uses_quoted_identifier=1
   AND execute_as_principal_id IS NULL AND is_schema_bound=0)
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@id)
 THROW 51973,'Observer module postimage differs: tr_P02MaintenanceObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.triggers WHERE object_id=@id AND type='TR'
 AND parent_class=1 AND parent_id=OBJECT_ID(N'dbo.MaintenanceWork') AND is_disabled=0 AND is_not_for_replication=0
 AND is_instead_of_trigger=0)
 THROW 51973,'Observer trigger state differs: tr_P02MaintenanceObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.objects o JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE o.object_id=@id AND o.type='TR' AND s.name=N'dbo'
 AND USER_NAME(COALESCE(o.principal_id,s.principal_id))=N'dbo')
 THROW 51973,'Observer object owner/type differs: tr_P02MaintenanceObservation.',1;

IF NOT EXISTS(SELECT 1 FROM sys.sequences s JOIN sys.schemas sc ON sc.schema_id=s.schema_id
 WHERE sc.name=N'dbo' AND s.name=N'P02ObservationGeneration' AND TYPE_NAME(s.user_type_id)=N'bigint'
 AND s.user_type_id=s.system_type_id AND CONVERT(bigint,s.start_value)=1 AND CONVERT(bigint,s.increment)=1
 AND CONVERT(bigint,s.minimum_value)=1 AND CONVERT(bigint,s.maximum_value)=9223372036854775807
 AND s.is_cycling=0 AND s.is_cached=0 AND s.cache_size IS NULL AND s.is_exhausted=0
 AND CONVERT(bigint,s.current_value)>=1 AND CONVERT(bigint,s.current_value)<9223372036854775807
 AND s.create_date=s.modify_date AND USER_NAME(COALESCE(s.principal_id,sc.principal_id))=N'dbo')
 THROW 51973,'Observer sequence structure/state differs.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02BeginCatalogueMutation') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='EXECUTE' AND state='G')<>1
 THROW 51973,'Observer permission postimage differs: dbo.usp_P02BeginCatalogueMutation/EXECUTE.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02EndCatalogueMutation') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='EXECUTE' AND state='G')<>1
 THROW 51973,'Observer permission postimage differs: dbo.usp_P02EndCatalogueMutation/EXECUTE.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.usp_P02ReadObservationBoundary') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='EXECUTE' AND state='G')<>1
 THROW 51973,'Observer permission postimage differs: dbo.usp_P02ReadObservationBoundary/EXECUTE.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.KVKFinalReportHeader') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='ALTER' AND state='D')<>1
 THROW 51973,'Observer permission postimage differs: dbo.KVKFinalReportHeader/ALTER.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceKvkWork') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='ALTER' AND state='D')<>1
 THROW 51973,'Observer permission postimage differs: dbo.MaintenanceKvkWork/ALTER.',1;

IF (SELECT COUNT(*) FROM sys.database_permissions
 WHERE class=1 AND major_id=OBJECT_ID(N'dbo.MaintenanceWork') AND minor_id=0
 AND grantee_principal_id=DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader')
 AND grantor_principal_id=DATABASE_PRINCIPAL_ID(N'dbo') AND permission_name='ALTER' AND state='D')<>1
 THROW 51973,'Observer permission postimage differs: dbo.MaintenanceWork/ALTER.',1;
