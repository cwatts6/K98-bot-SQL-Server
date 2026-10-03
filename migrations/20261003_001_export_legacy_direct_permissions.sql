/*
MigrationId: 20261003_001_export_legacy_direct_permissions
Purpose: Operator-approved direct legacy capabilities; no module signing or procedure rewrite
Author: cwatts
CreatedUtc: 2026-10-03
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
-- Exact session inputs required; generic filename deployment is insufficient.
-- #S11LegacyDirectDeployment(ExpectedServer nvarchar(128), ExpectedDatabase sysname,
-- ManifestHash char(64), ApprovalHash binary(32)); exactly one separately approved row.
SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;
IF @@TRANCOUNT<>0 THROW 52117,'Own migration transaction required.',1;
IF TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))<>16 OR COALESCE(IS_SRVROLEMEMBER('sysadmin'),0)<>1 THROW 52117,'SQL2022 administrator installation required.',1;
IF OBJECT_ID(N'tempdb..#S11LegacyDirectDeployment') IS NULL THROW 52117,'Exact approved direct deployment inputs required.',1;
IF (SELECT COUNT(*) FROM #S11LegacyDirectDeployment)<>1 OR NOT EXISTS(SELECT 1 FROM #S11LegacyDirectDeployment WHERE ExpectedServer COLLATE Latin1_General_100_BIN2=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AND ExpectedDatabase COLLATE Latin1_General_100_BIN2=DB_NAME() AND ManifestHash COLLATE Latin1_General_100_BIN2=N'c018e31d759239840e6f43679c9e05d5f9bddfdad166e9d299d76e3c6b1799e6' AND DATALENGTH(ApprovalHash)=32 AND ApprovalHash<>0x0000000000000000000000000000000000000000000000000000000000000000) THROW 52117,'Approved target/source/decision bindings differ.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportLegacyEntryReader') IS NOT NULL OR EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name IN(N'S11LegacyPermissionManifest',N'S11LegacyDirectPermissionManifest')) THROW 52117,'Existing legacy permission delivery is not adopted; reconcile.',1;
IF EXISTS(SELECT 1 FROM sys.certificates WHERE name IN(N'S11LegacyImport',N'S11LegacyTargets',N'S11LegacyStats')) THROW 52117,'Unexpected legacy signing delivery; do not silently replace.',1;
IF DATABASE_PRINCIPAL_ID(N'ExportExecutionAuthority') IS NULL THROW 52117,'Prior evidence role installation required.',1;
DECLARE @Modules table(ModuleName nvarchar(257) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,DefinitionHash binary(32),ObjectType char(2),ExecuteAsPrincipal int NULL);
INSERT @Modules VALUES
(N'KVK.sp_KVK_AllPlayers_Ingest',0xd574dfbd2896f5491e59923be165901fb658d6ee5b766a70f3c97c24767c9a20,'P',NULL),
(N'KVK.sp_KVK_Get_Exports',0x545952ae65e57b0f592e5b9c1e9a5c0f1a1b74b354d96ff6764357e28cade29b,'P',NULL),
(N'KVK.sp_KVK_Recompute_Windows',0x51cd44ffc4c7f1929a6ecbe29295da96bcec2c18c5589f0c1d497a3959d66356,'P',NULL),
(N'dbo.ACQUIRE_KS4_IMPORT_LOCK',0xb600e0d4cac9ebda6fe1657386cd61fe105d3f597192e10e776788f77cb0c10c,'P',-2),
(N'dbo.ARCHIVE_IMPORT_STAGING_FILE',0xae8d625386af7dec301e9b43126e455c31556047a198d1a3adb3b8f89e1e2dda,'P',NULL),
(N'dbo.CLAIM_KS4_IMPORT_FILE',0xb6a711b888684eb515f87b7de516043e1d384d8fea2bcc8adcb35afa514dc7ca,'P',NULL),
(N'dbo.CREATE_DASH2',0x32ec93c823b11800911d4fc7123fdf6730c1563de072703602a46bc36ccfe718,'P',NULL),
(N'dbo.CREATE_DELTA_TABLES',0xe4c9150e8f8d5434f77cc2238e444891a56f02e5aa312eab182e7f4b0f0591ab,'P',NULL),
(N'dbo.CREATE_THE_AVERAGES',0x714359292281d729de77df2b2883f431552d243ba537cce35f18b37e2d3f267a,'P',NULL),
(N'dbo.DEADSSUMMARY_PROC',0x3688d1adbc52dbf6f2686080fa789d2cb94522f0053b9c72120943994e2e6277,'P',NULL),
(N'dbo.GOVERNOR_NAMES_PROC',0xba171a53114fa45d03434ce038c09a4e66eaa59134006c8f6d5251b4b462e92e,'P',NULL),
(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE',0xdad532fb6309e6b9418806bc2e1142237c3e467c411ba6e833a95bf19db81207,'P',NULL),
(N'dbo.HEALEDSUMMARY_PROC',0xbdb4dc1e56b9bf2b4fdf50d03ebf068551d630c87ce2ab55b31f809e60e6bfed,'P',NULL),
(N'dbo.IMPORT_STAGING_PROC_CORE',0xc8a197d90fc7aea7d4e51935e39b7031203e25e41626847b6d9e0dd50867fd8c,'P',NULL),
(N'dbo.KILLPOINTSSUMMARY_PROC',0x294bee151bf87885b1500c1ac7274f53e6e4d600513c9b457b4c2e475c8f72ae,'P',NULL),
(N'dbo.KILLSSUMMARY_PROC',0xff8798becd4c3cd300e2eddee1592066bd626a15fc69db4c81cf57b77ae8fbc2,'P',NULL),
(N'dbo.KT4SUMMARY_PROC',0x34d3a01a15f6b05e7eee503ea760f493dd5086d548a0ff7eb5de29e6b6cf979c,'P',NULL),
(N'dbo.KT5SUMMARY_PROC',0x56288be469a924d16f821a40c3885bd12e07f80bfa6af29f781bca9d507c24d5,'P',NULL),
(N'dbo.POWERSUMMARY_PROC',0x1259508d96b6267e6b8b8508a3b069301254329d26fcb3a6871fb88247b64c3e,'P',NULL),
(N'dbo.RANGEDSUMMARY_PROC',0x786ca62850c9f55270844dace6782278f0dbca3451e46e6d4f47b56fb9848c79,'P',NULL),
(N'dbo.Refresh_PlayerScanMeta',0xc5e6b156de73e9271b9545897ad77836e4b1ce3d34bc08f641ae73d97e9d6187,'P',NULL),
(N'dbo.SP_Stats_for_Upload',0xf027787931efdc66e8302a8576241aa046fd7b1512ecfcd31a3d186be53965ac,'P',NULL),
(N'dbo.SUMMARY_PROC',0xa4c1af34ff6c8d959375b77b1ee68294adb896379ff0d777e517170a8ffd78a1,'P',NULL),
(N'dbo.UPDATE_ALL2',0xd89d8cdd46020f3a464baf5cb0cbc1f30fb5734efe36316865dac88cabd24b68,'P',NULL),
(N'dbo.fn_NormalizeGovernorNameKey',0x46e14cc25edf211145d2cfa64e125ecd5286e6de44605ac6d4fc68a2bdb2cfac,'FN',NULL),
(N'dbo.sp_Build_Prekvk_And_Honor_Rankings',0x3402b78fb19f7add67281c151522a88f14177c7a87e6c193b4f90bd374f797b1,'P',NULL),
(N'dbo.sp_Create_Excel_For_Kvk_Indexes',0xc4860487e09f82e0ceba3dbafd36df203f1506ca2af95d62832af86b10cd4f5f,'P',NULL),
(N'dbo.sp_ExcelOutput_ByKVK',0xecc7ae0efcb942e159459d51088bea281efcee6a3c711f9123dacef8d67c50fc,'P',NULL),
(N'dbo.sp_Prep_ExcelExportTable',0xe79bf39bdbf265eac79cf54c00ac15a6240becc74f3fc9fc685de12eaec0c6f2,'P',NULL),
(N'dbo.sp_Prep_ExcelOutputTable',0x249a81e94fdac9f17bb927e9845c2bc4642c66e0455b44dc0c631b471a754f8d,'P',NULL),
(N'dbo.sp_Prep_TargetTable',0x14dc95d4380b2fe1af03c8615d9284d82bb0c3f326c4ba5389058537a063537a,'P',NULL),
(N'dbo.sp_Rebuild_ExcelForDashboard',0x6759004fe3110f5648c6825abacbe2b14d70f333dd9091a4239a23c54d986b45,'P',NULL),
(N'dbo.sp_RefreshInactiveGovernors',0x21a85705ff145f064a133bc42ccb5edb415fa7eb8543ae4ccec464bf04bcc994,'P',NULL),
(N'dbo.sp_Refresh_View_EXCEL_FOR_KVK_All',0x17d436196b6bc5ddd9c1cdbcd63ed46c39c9b3c9ef821382c22cb5b389e963cc,'P',NULL),
(N'dbo.sp_TARGETS_MASTER',0xd20e2dc29c7d6455a17ebfcb59e78210e1c10aa20145974293ac5f417822ec20,'P',NULL),
(N'dbo.sp_Upsert_ProcConfig_From_Staging',0x1ab729a83b8e8674ef087f767e862b641841f2a89dc1ed30c618d7d8011476a6,'P',-2),
(N'dbo.usp_RecordKvkFinalReportCompletion',0x195d14e5dc42d17a8e4fa8bd632e61fbfe5f6ad43ec7e54bf1ef5fce61a441a7,'P',NULL),
(N'dbo.usp_UpsertGovernorNameHistoryForScan',0x568b9d55e04a660c75571e136d4e33d59901f357f51d6d8e2b20a9dd59442ab6,'P',NULL);
DECLARE @CompatibleDefinitions table(ModuleName nvarchar(257) COLLATE Latin1_General_100_BIN2,DefinitionHash binary(32),PRIMARY KEY(ModuleName,DefinitionHash));
INSERT @CompatibleDefinitions VALUES
(N'KVK.sp_KVK_AllPlayers_Ingest',0x4e4955c323d86e2c9e81e291e9810aded77bcfed892d4edca3c59fd573b9623e),
(N'KVK.sp_KVK_Get_Exports',0x474067e3369edaca6161f84e3c9364206a4fa44acffa0588a59883a5e0ec0ce8),
(N'dbo.ACQUIRE_KS4_IMPORT_LOCK',0x6e8921159a22e1f06dacac81dcca9af85722e524ae9c78f680299e9881d0df5b),
(N'dbo.CREATE_DELTA_TABLES',0xff21ecb032b929abf1333b4f699b360a5a033bf3a2e10166aa38035f0b2dc6d8),
(N'dbo.DEADSSUMMARY_PROC',0x5105a600f8d628726b039217081b0fbe8c33a8a9c90570a97f4c23daf7d170a3),
(N'dbo.HEALEDSUMMARY_PROC',0x01df5a9769a90c78831e84463ab5c889f0dcf7c1c33ce31f740fe393dfd54d28),
(N'dbo.KILLPOINTSSUMMARY_PROC',0x72222f1fc92ad53cf3daa148068579d59205926fdf0f74e12014474ac9385d5b),
(N'dbo.KILLSSUMMARY_PROC',0xebe4551b755d36e22c8fc4c548e5985f5370bd04c31d80868e750abaa49f1143),
(N'dbo.KT4SUMMARY_PROC',0x8153007c15b8b9108144f1411e9103f6c6bffd8142f6fbd4f1a5a54260371a12),
(N'dbo.KT5SUMMARY_PROC',0xdef6dcc8f40e17f1ecff3a669ce15a2d29aa97756a15596e32ba06dfe7f47acf),
(N'dbo.POWERSUMMARY_PROC',0xd3ad66170f6f70cd679b03b18ed46b6e75c4ccf4a77015493f594d971dbdaf2d),
(N'dbo.RANGEDSUMMARY_PROC',0x60081f590a2b49438e44c7d1e60dd461a78b6f568b72a4fd6c7c2f7636078bae),
(N'dbo.Refresh_PlayerScanMeta',0x62266c69f1daf40c2150a6d0369a8ffa93fc1f3ada7f48d66ebb6b4b3f03ccd1),
(N'dbo.SP_Stats_for_Upload',0x39c63023c69c8d1bf54088e58dc8949d3271768b1512fe02877efcb09e917d92),
(N'dbo.SUMMARY_PROC',0x73d9af67cd5516e870ed755542439d5977f6dff51da8dc1795434af1da3411e5),
(N'dbo.UPDATE_ALL2',0xcbe4077f8f1f2f92bccede963f19919665f4fcefe63def90fd834bf92a723cc9),
(N'dbo.fn_NormalizeGovernorNameKey',0xc462b37844e58e2a9e91ed119d984c48cafe0f4df7cf426092cb0e18d190cec1),
(N'dbo.sp_Create_Excel_For_Kvk_Indexes',0xe4e25af8f320f7a6c5638a301ea7017c215a1d490a869b89645d56aea13a4999),
(N'dbo.sp_ExcelOutput_ByKVK',0x019081cad5a1769bef54e908debfbbf84b4cbe0ab247621c50d0d4f912e31406),
(N'dbo.sp_Prep_ExcelExportTable',0xec723069c9a743650fcee2e3f5f48f6d0db7b89b2b6bf787226694d78bef1194),
(N'dbo.sp_Prep_ExcelOutputTable',0x13398d6e860dd2a052bba3147f2d4b733b0ab88944ab685a2bfd9fd0328a548f),
(N'dbo.sp_Prep_TargetTable',0xdb7bf19c90d092c516744b3fb5b3cdbdcd3d5307c7e2d69fb19fb5600d429299),
(N'dbo.sp_Rebuild_ExcelForDashboard',0xb83ffcc7e576baa116a7085ed97522991713eef8655e233e46665c6b9f3894a6),
(N'dbo.sp_RefreshInactiveGovernors',0x323e66e9a12a033012f5d03d28789df67a04562a95346c5e8280fd4cc6c009f4),
(N'dbo.sp_TARGETS_MASTER',0xf298271b8e7a57e5cce55bca88cd2aa21a1243ebce0a5c0a9559fce1fd600a3e),
(N'dbo.usp_RecordKvkFinalReportCompletion',0x3ada96d3bcc82eb5beb9d2c5989c0e4482f0335008dce6d7f79444565f79562c),
(N'dbo.usp_UpsertGovernorNameHistoryForScan',0xf420251839fa87b4e358a892a64e5f830f4ac945b0d72eeff411a4418877e97f);
DECLARE @Name nvarchar(257),@Expected binary(32),@Type char(2),@ExecuteAs int,@Definition nvarchar(max);
BEGIN TRANSACTION;
BEGIN TRY
 DECLARE @Lock int;
 EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @Lock<0 THROW 52117,'Schema busy.',1;
 DECLARE modules CURSOR LOCAL FAST_FORWARD FOR SELECT ModuleName,DefinitionHash,ObjectType,ExecuteAsPrincipal FROM @Modules;
 OPEN modules; FETCH NEXT FROM modules INTO @Name,@Expected,@Type,@ExecuteAs;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @Definition=NULL;
  SELECT @Definition=m.definition FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id JOIN sys.schemas s ON s.schema_id=o.schema_id WHERE m.object_id=OBJECT_ID(@Name) AND o.type COLLATE Latin1_General_100_BIN2=@Type COLLATE Latin1_General_100_BIN2 AND COALESCE(o.principal_id,s.principal_id)=DATABASE_PRINCIPAL_ID(N'dbo') AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1 AND ISNULL(m.execute_as_principal_id,0)=ISNULL(@ExecuteAs,0);
  IF @Definition IS NULL THROW 52117,'Exact source module/context/owner unavailable.',1;
  SET @Definition=REPLACE(@Definition,NCHAR(13)+NCHAR(10),NCHAR(10));
  WHILE LEFT(@Definition,1) IN(N' ',NCHAR(9),NCHAR(10),NCHAR(13)) SET @Definition=STUFF(@Definition,1,1,N'');
  WHILE RIGHT(@Definition,1) IN(N' ',NCHAR(9),NCHAR(10),NCHAR(13)) SET @Definition=LEFT(@Definition COLLATE Latin1_General_100_BIN2,DATALENGTH(@Definition)/2-1);
  IF LEFT(@Definition,15) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER' SET @Definition=STUFF(@Definition,1,15,N'CREATE');
  ELSE IF LEFT(@Definition,5) COLLATE Latin1_General_100_BIN2=N'ALTER' SET @Definition=STUFF(@Definition,1,5,N'CREATE');
  IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Definition))<>@Expected AND NOT EXISTS(SELECT 1 FROM @CompatibleDefinitions WHERE ModuleName=@Name AND DefinitionHash=HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Definition))) THROW 52117,'Legacy module differs from reviewed source; stop.',1;
  IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(@Name)) THROW 52117,'Unexpected existing signature; preserve and reconcile.',1;
  FETCH NEXT FROM modules INTO @Name,@Expected,@Type,@ExecuteAs;
 END;
 CLOSE modules; DEALLOCATE modules;
 CREATE ROLE ExportLegacyEntryReader AUTHORIZATION dbo;
 GRANT EXECUTE ON OBJECT::[KVK].[sp_KVK_AllPlayers_Ingest] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[KVK].[sp_KVK_Get_Exports] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[KVK].[sp_KVK_Recompute_Windows] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[dbo].[SP_Stats_for_Upload] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[dbo].[UPDATE_ALL2] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[dbo].[sp_TARGETS_MASTER] TO [ExportLegacyEntryReader];
 GRANT EXECUTE ON OBJECT::[dbo].[sp_Upsert_ProcConfig_From_Staging] TO [ExportLegacyEntryReader];
 GRANT CHECKPOINT TO [ExportLegacyEntryReader];
 GRANT CREATE TABLE TO [ExportLegacyEntryReader];
 GRANT CREATE VIEW TO [ExportLegacyEntryReader];
 GRANT VIEW DATABASE PERFORMANCE STATE TO [ExportLegacyEntryReader];
 GRANT ALTER ON SCHEMA::[dbo] TO [ExportLegacyEntryReader];
 GRANT INSERT ON SCHEMA::[dbo] TO [ExportLegacyEntryReader];
 GRANT SELECT ON SCHEMA::[dbo] TO [ExportLegacyEntryReader];
 GRANT ALTER ON OBJECT::[dbo].[STATS_FOR_UPLOAD] TO [ExportLegacyEntryReader];
 EXEC sys.sp_addextendedproperty @name=N'S11LegacyDirectPermissionManifest',@value=N'c018e31d759239840e6f43679c9e05d5f9bddfdad166e9d299d76e3c6b1799e6';
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
-- Role-only installation. SID-bound application/master users and server grants are separate.
-- No application membership, login enable, xp enable/proxy, workflow invocation or activation.
