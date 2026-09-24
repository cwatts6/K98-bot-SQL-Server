-- AUTHORING ONLY. Separately approved read-only G4 metadata verification.
-- Requires the same exact session-local public certificate/signature packet as
-- installation, with Action='verify'. It never calls a business module/provider.
-- Run with separately approved complete metadata visibility, not borrowed Bot
-- credentials; this report does not certify the Bot's effective token or OS ACLs.
SET NOCOUNT ON;
DECLARE @Action varchar(16)='verify';

DECLARE @ManifestHash char(64)='ea8657c227ca541e8d00db2ad757b9569c52b03061d37a8f03c9bc220a33afc2';
IF DB_NAME() COLLATE Latin1_General_100_BIN2<>N'ROK_TRACKER'
 OR TRY_CONVERT(int,SERVERPROPERTY('ProductMajorVersion'))<>16
 THROW 51730,'Exact SQL Server 2022 ROK_TRACKER target required.',1;
IF OBJECT_ID(N'tempdb..#S11LegacyDeployment') IS NULL
 OR OBJECT_ID(N'tempdb..#S11LegacySignatures') IS NULL
 THROW 51730,'Separate approved G4 deployment/signature inputs required.',1;
IF (SELECT COUNT(*) FROM #S11LegacyDeployment)<>1
 OR NOT EXISTS(SELECT 1 FROM #S11LegacyDeployment WHERE ExpectedServer COLLATE Latin1_General_100_BIN2=CONVERT(nvarchar(128),SERVERPROPERTY('ServerName'))
 AND ManifestHash COLLATE Latin1_General_100_BIN2=@ManifestHash AND DATALENGTH(ApprovalHash)=32 AND ApprovalHash<>0x0000000000000000000000000000000000000000000000000000000000000000 AND Action COLLATE Latin1_General_100_BIN2=@Action)
 THROW 51730,'Exact target, source manifest, action and approval receipt required.',1;
DECLARE @Modules table(ModuleName nvarchar(257) COLLATE Latin1_General_100_BIN2 PRIMARY KEY,
 DefinitionHash binary(32),ObjectType char(2),ExecuteAsPrincipal int NULL);
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
DECLARE @ExpectedSignatures table(ModuleName nvarchar(257) COLLATE Latin1_General_100_BIN2,
 CertificateName sysname COLLATE Latin1_General_100_BIN2,CryptType char(4),PRIMARY KEY(ModuleName,CertificateName));
INSERT @ExpectedSignatures VALUES
(N'dbo.ARCHIVE_IMPORT_STAGING_FILE',N'S11LegacyImport','CPVC'),
(N'dbo.CLAIM_KS4_IMPORT_FILE',N'S11LegacyImport','CPVC'),
(N'dbo.CREATE_DASH2',N'S11LegacyImport','CPVC'),
(N'dbo.CREATE_DELTA_TABLES',N'S11LegacyTargets','CPVC'),
(N'dbo.CREATE_THE_AVERAGES',N'S11LegacyImport','CPVC'),
(N'dbo.GOVERNOR_NAMES_PROC',N'S11LegacyImport','CPVC'),
(N'dbo.HASH_KS4_IMPORT_ARCHIVE_FILE',N'S11LegacyImport','CPVC'),
(N'dbo.IMPORT_STAGING_PROC_CORE',N'S11LegacyImport','CPVC'),
(N'dbo.Refresh_PlayerScanMeta',N'S11LegacyImport','CPVC'),
(N'dbo.SP_Stats_for_Upload',N'S11LegacyStats','SPVC'),
(N'dbo.SUMMARY_PROC',N'S11LegacyImport','CPVC'),
(N'dbo.UPDATE_ALL2',N'S11LegacyImport','SPVC'),
(N'dbo.sp_Build_Prekvk_And_Honor_Rankings',N'S11LegacyImport','CPVC'),
(N'dbo.sp_Build_Prekvk_And_Honor_Rankings',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_Create_Excel_For_Kvk_Indexes',N'S11LegacyImport','CPVC'),
(N'dbo.sp_Create_Excel_For_Kvk_Indexes',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_ExcelOutput_ByKVK',N'S11LegacyImport','CPVC'),
(N'dbo.sp_ExcelOutput_ByKVK',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_Prep_ExcelExportTable',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_Prep_ExcelOutputTable',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_Prep_TargetTable',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_Rebuild_ExcelForDashboard',N'S11LegacyImport','CPVC'),
(N'dbo.sp_RefreshInactiveGovernors',N'S11LegacyImport','CPVC'),
(N'dbo.sp_Refresh_View_EXCEL_FOR_KVK_All',N'S11LegacyImport','CPVC'),
(N'dbo.sp_Refresh_View_EXCEL_FOR_KVK_All',N'S11LegacyTargets','CPVC'),
(N'dbo.sp_TARGETS_MASTER',N'S11LegacyTargets','SPVC');
IF EXISTS(SELECT ModuleName,CertificateName,CryptType FROM @ExpectedSignatures EXCEPT
 SELECT ModuleName COLLATE Latin1_General_100_BIN2,CertificateName COLLATE Latin1_General_100_BIN2,CryptType COLLATE Latin1_General_100_BIN2 FROM #S11LegacySignatures)
 OR EXISTS(SELECT ModuleName COLLATE Latin1_General_100_BIN2,CertificateName COLLATE Latin1_General_100_BIN2,CryptType COLLATE Latin1_General_100_BIN2 FROM #S11LegacySignatures EXCEPT
 SELECT ModuleName,CertificateName,CryptType FROM @ExpectedSignatures)
 OR (SELECT COUNT(*) FROM #S11LegacySignatures)<>(SELECT COUNT(*) FROM @ExpectedSignatures)
 OR EXISTS(SELECT 1 FROM #S11LegacySignatures WHERE Thumbprint IS NULL OR DATALENGTH(Thumbprint)<>20
 OR Signature IS NULL OR DATALENGTH(Signature) NOT BETWEEN 128 AND 8000)
 THROW 51730,'Missing, extra, duplicate or invalid signature input.',1;
IF EXISTS(SELECT CertificateName FROM #S11LegacySignatures GROUP BY CertificateName HAVING COUNT(DISTINCT Thumbprint)<>1)
 OR (SELECT COUNT(DISTINCT Thumbprint) FROM #S11LegacySignatures)<>3
 THROW 51730,'Distinct pinned certificate identities required.',1;
IF EXISTS(SELECT 1 FROM #S11LegacySignatures s LEFT JOIN sys.certificates c ON c.name=s.CertificateName COLLATE Latin1_General_100_BIN2
 WHERE c.certificate_id IS NULL OR c.thumbprint<>s.Thumbprint OR c.pvt_key_encryption_type<>'NA'
 OR c.principal_id<>DATABASE_PRINCIPAL_ID(N'dbo'))
 THROW 51730,'Approved public-only dbo-owned signing certificate unavailable.',1;
IF NOT EXISTS(SELECT 1 FROM master.sys.certificates c JOIN sys.certificates d ON d.name=c.name COLLATE Latin1_General_100_BIN2 AND d.thumbprint=c.thumbprint
 WHERE c.name=N'S11LegacyImport' AND c.pvt_key_encryption_type='NA' AND c.principal_id=1)
 THROW 51730,'Matching public-only import certificate in master required.',1;
DECLARE @MasterCertificateBytes varbinary(max);
EXEC master.sys.sp_executesql N'SELECT @Value=CERTENCODED(CERT_ID(N''S11LegacyImport''));',
 N'@Value varbinary(max) OUTPUT',@Value=@MasterCertificateBytes OUTPUT;
IF @MasterCertificateBytes IS NULL OR @MasterCertificateBytes<>CERTENCODED(CERT_ID(N'S11LegacyImport'))
 THROW 51730,'Import certificates must have byte-identical public encodings.',1;
-- Canonical comparison changes only the DDL introducer and outer whitespace.
-- Signature blobs still bind exact installed bytes, including all line endings.
DECLARE @ModuleName nvarchar(257),@Definition nvarchar(max),@ExpectedHash binary(32),@ObjectType char(2),@ExecuteAs int;
DECLARE definitions CURSOR LOCAL FAST_FORWARD FOR SELECT ModuleName,DefinitionHash,ObjectType,ExecuteAsPrincipal FROM @Modules;
OPEN definitions;
FETCH NEXT FROM definitions INTO @ModuleName,@ExpectedHash,@ObjectType,@ExecuteAs;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @Definition=NULL;
 SELECT @Definition=m.definition FROM sys.sql_modules m JOIN sys.objects o ON o.object_id=m.object_id
 JOIN sys.schemas s ON s.schema_id=o.schema_id
 WHERE m.object_id=OBJECT_ID(@ModuleName) AND o.type=@ObjectType AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
 AND ISNULL(m.execute_as_principal_id,0)=ISNULL(@ExecuteAs,0)
 AND COALESCE(o.principal_id,s.principal_id)=DATABASE_PRINCIPAL_ID(N'dbo');
 IF @Definition IS NULL THROW 51730,'Required source module/owner/SET options unavailable.',1;
 SET @Definition=REPLACE(@Definition,NCHAR(13)+NCHAR(10),NCHAR(10));
 WHILE LEFT(@Definition,1) IN (N' ',NCHAR(9),NCHAR(10),NCHAR(13)) SET @Definition=STUFF(@Definition,1,1,N'');
 WHILE RIGHT(@Definition,1) IN (N' ',NCHAR(9),NCHAR(10),NCHAR(13)) SET @Definition=LEFT(@Definition COLLATE Latin1_General_100_BIN2,DATALENGTH(@Definition)/2-1);
 IF LEFT(@Definition,15) COLLATE Latin1_General_100_BIN2=N'CREATE OR ALTER' SET @Definition=STUFF(@Definition,1,15,N'CREATE');
 ELSE IF LEFT(@Definition,5) COLLATE Latin1_General_100_BIN2=N'ALTER' SET @Definition=STUFF(@Definition,1,5,N'CREATE');
 IF HASHBYTES('SHA2_256',CONVERT(varbinary(max),@Definition))<>@ExpectedHash
 THROW 51730,'Module definition differs from independently approved source; never sign installed drift.',1;
 FETCH NEXT FROM definitions INTO @ModuleName,@ExpectedHash,@ObjectType,@ExecuteAs;
END;
CLOSE definitions;
DEALLOCATE definitions;
-- Guard metadata-derived identifiers in unchanged business modules.
IF EXISTS(SELECT 1 FROM sys.tables WHERE schema_id<>SCHEMA_ID(N'dbo') AND
 (name LIKE N'EXCEL_FOR_KVK[_]%' OR name IN
 (N'T4KillDelta',N'T5KillDelta',N'T4T5KillDelta',N'POWERDelta',N'KillPointsDelta',N'DeadsDelta',N'HelpsDelta',N'RSSASSISTDelta',N'RSSGatheredDelta',N'HealedTroopsDelta',N'RangedPointsDelta',N'DeltaMetrics',N'kingdomscandata4')))
 OR EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id WHERE CHARINDEX(N']',i.name)>0 AND
 t.name IN (N'T4KillDelta',N'T5KillDelta',N'T4T5KillDelta',N'POWERDelta',N'KillPointsDelta',N'DeadsDelta',N'HelpsDelta',N'RSSASSISTDelta',N'RSSGatheredDelta',N'HealedTroopsDelta',N'RangedPointsDelta',N'DeltaMetrics',N'kingdomscandata4'))
 THROW 51730,'Unreviewed dynamic identifier metadata; root remains closed.',1;
DECLARE @ExpectedGrants table(DatabaseName sysname,PrincipalName sysname,SecurableClass nvarchar(32),TargetName nvarchar(257),PermissionName nvarchar(128));
INSERT @ExpectedGrants VALUES
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'KVK.sp_KVK_AllPlayers_Ingest',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'KVK.sp_KVK_Get_Exports',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'KVK.sp_KVK_Recompute_Windows',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'dbo.SP_Stats_for_Upload',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'dbo.UPDATE_ALL2',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'dbo.sp_TARGETS_MASTER',N'EXECUTE'),
(N'ROK_TRACKER',N'ExportLegacyEntryReader',N'OBJECT',N'dbo.sp_Upsert_ProcConfig_From_Staging',N'EXECUTE'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'DATABASE',N'ROK_TRACKER',N'CHECKPOINT'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'DATABASE',N'ROK_TRACKER',N'CREATE TABLE'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'DATABASE',N'ROK_TRACKER',N'CREATE VIEW'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'DATABASE',N'ROK_TRACKER',N'VIEW DATABASE PERFORMANCE STATE'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'SCHEMA',N'dbo',N'ALTER'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'SCHEMA',N'dbo',N'INSERT'),
(N'ROK_TRACKER',N'S11LegacyImportUser',N'SCHEMA',N'dbo',N'SELECT'),
(N'ROK_TRACKER',N'S11LegacyStatsUser',N'OBJECT',N'dbo.STATS_FOR_UPLOAD',N'ALTER'),
(N'ROK_TRACKER',N'S11LegacyStatsUser',N'SCHEMA',N'dbo',N'SELECT'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'DATABASE',N'ROK_TRACKER',N'CREATE TABLE'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'DATABASE',N'ROK_TRACKER',N'CREATE VIEW'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'DATABASE',N'ROK_TRACKER',N'VIEW DATABASE PERFORMANCE STATE'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'SCHEMA',N'dbo',N'ALTER'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'SCHEMA',N'dbo',N'INSERT'),
(N'ROK_TRACKER',N'S11LegacyTargetsUser',N'SCHEMA',N'dbo',N'SELECT'),
(N'master',N'S11LegacyImportLogin',N'SERVER',N'',N'ADMINISTER BULK OPERATIONS'),
(N'master',N'S11LegacyImportLogin',N'SERVER',N'',N'VIEW SERVER PERFORMANCE STATE'),
(N'master',N'S11LegacyImportUser',N'OBJECT',N'dbo.xp_cmdshell',N'EXECUTE'),
(N'master',N'S11LegacyImportUser',N'OBJECT',N'dbo.xp_fileexist',N'EXECUTE');

-- Exact capabilities, not just names or counts. No memberships for signing users.
DECLARE @ActualGrants table(DatabaseName sysname,PrincipalName sysname,SecurableClass nvarchar(32),TargetName nvarchar(257),PermissionName nvarchar(128));
INSERT @ActualGrants
 SELECT DB_NAME(),u.name,p.class_desc,CASE p.class WHEN 0 THEN DB_NAME() WHEN 3 THEN SCHEMA_NAME(p.major_id)
 WHEN 1 THEN OBJECT_SCHEMA_NAME(p.major_id)+N'.'+OBJECT_NAME(p.major_id) ELSE N'UNSUPPORTED' END,p.permission_name
 FROM sys.database_permissions p JOIN sys.database_principals u ON u.principal_id=p.grantee_principal_id
 WHERE u.name IN (N'S11LegacyImportUser',N'S11LegacyTargetsUser',N'S11LegacyStatsUser',N'ExportLegacyEntryReader');
INSERT @ActualGrants
 SELECT N'master',u.name,p.class_desc,CASE p.class WHEN 1 THEN N'dbo.'+OBJECT_NAME(p.major_id,DB_ID(N'master')) ELSE N'UNSUPPORTED' END,p.permission_name
 FROM master.sys.database_permissions p JOIN master.sys.database_principals u ON u.principal_id=p.grantee_principal_id
 WHERE u.name=N'S11LegacyImportUser';
INSERT @ActualGrants SELECT N'master',s.name,N'SERVER',N'',p.permission_name FROM sys.server_permissions p
 JOIN sys.server_principals s ON s.principal_id=p.grantee_principal_id WHERE s.name=N'S11LegacyImportLogin';
-- SQL catalog class_desc uses OBJECT_OR_COLUMN; the contract uses OBJECT.
UPDATE @ActualGrants SET SecurableClass=N'OBJECT' WHERE SecurableClass=N'OBJECT_OR_COLUMN';
IF EXISTS(SELECT * FROM @ActualGrants EXCEPT SELECT * FROM @ExpectedGrants)
 OR EXISTS(SELECT * FROM @ExpectedGrants EXCEPT SELECT * FROM @ActualGrants)
 OR (SELECT COUNT(*) FROM @ActualGrants)<>(SELECT COUNT(*) FROM @ExpectedGrants)
 OR EXISTS(SELECT 1 FROM sys.database_permissions p JOIN sys.database_principals u ON u.principal_id=p.grantee_principal_id
 WHERE u.name IN (N'S11LegacyImportUser',N'S11LegacyTargetsUser',N'S11LegacyStatsUser',N'ExportLegacyEntryReader') AND (p.state<>'G' OR p.minor_id<>0))
 OR EXISTS(SELECT 1 FROM master.sys.database_permissions p JOIN master.sys.database_principals u ON u.principal_id=p.grantee_principal_id
 WHERE u.name=N'S11LegacyImportUser' AND (p.state<>'G' OR p.minor_id<>0))
 OR EXISTS(SELECT 1 FROM sys.server_permissions p JOIN sys.server_principals u ON u.principal_id=p.grantee_principal_id WHERE u.name=N'S11LegacyImportLogin' AND p.state<>'G')
 THROW 51730,'Certificate/entry role grants differ; preserve and reconcile.',1;
IF EXISTS(SELECT 1 FROM sys.database_role_members r JOIN sys.database_principals u ON u.principal_id=r.member_principal_id
 WHERE u.name IN (N'S11LegacyImportUser',N'S11LegacyTargetsUser',N'S11LegacyStatsUser',N'ExportLegacyEntryReader'))
 OR EXISTS(SELECT 1 FROM master.sys.database_role_members r JOIN master.sys.database_principals u ON u.principal_id=r.member_principal_id WHERE u.name=N'S11LegacyImportUser')
 OR EXISTS(SELECT 1 FROM sys.server_role_members r JOIN sys.server_principals u ON u.principal_id=r.member_principal_id WHERE u.name=N'S11LegacyImportLogin')
 THROW 51730,'Signing principals/entry role must not inherit other roles.',1;
IF EXISTS(SELECT 1 FROM sys.database_principals u JOIN sys.certificates c ON c.name=REPLACE(u.name,N'User',N'')
 WHERE u.name IN (N'S11LegacyImportUser',N'S11LegacyTargetsUser',N'S11LegacyStatsUser') AND (u.type<>'C' OR u.sid<>c.sid))
 OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'ExportLegacyEntryReader' AND type='R' AND owning_principal_id=1)
 OR NOT EXISTS(SELECT 1 FROM master.sys.database_principals u JOIN master.sys.certificates c ON c.sid=u.sid WHERE u.name=N'S11LegacyImportUser' AND c.name=N'S11LegacyImport' AND u.type='C')
 OR NOT EXISTS(SELECT 1 FROM sys.server_principals u JOIN master.sys.certificates c ON c.sid=u.sid WHERE u.name=N'S11LegacyImportLogin' AND c.name=N'S11LegacyImport' AND u.type='C')
 THROW 51730,'Certificate principal identity differs.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties p JOIN @Modules m ON OBJECT_ID(m.ModuleName)=p.major_id
 WHERE p.class<>1 OR NOT EXISTS(SELECT 1 FROM #S11LegacySignatures s WHERE s.ModuleName COLLATE Latin1_General_100_BIN2=m.ModuleName
 AND s.Thumbprint=p.thumbprint AND s.CryptType COLLATE Latin1_General_100_BIN2=p.crypt_type AND s.Signature=p.crypt_property))
 OR EXISTS(SELECT 1 FROM #S11LegacySignatures s WHERE NOT EXISTS(SELECT 1 FROM sys.crypt_properties p
 WHERE p.class=1 AND p.major_id=OBJECT_ID(s.ModuleName) AND p.thumbprint=s.Thumbprint AND p.crypt_type=s.CryptType COLLATE Latin1_General_100_BIN2 AND p.crypt_property=s.Signature))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties p WHERE p.thumbprint IN (SELECT Thumbprint FROM #S11LegacySignatures)
 AND NOT EXISTS(SELECT 1 FROM @ExpectedSignatures s WHERE OBJECT_ID(s.ModuleName)=p.major_id AND s.CryptType=p.crypt_type))
 THROW 51730,'Unexpected, absent or different module signature bytes.',1;
IF EXISTS(SELECT 1 FROM #S11LegacySignatures s WHERE NOT EXISTS
 (SELECT 1 FROM sys.fn_check_object_signatures(N'certificate',s.Thumbprint) f
 WHERE f.entity_id=OBJECT_ID(s.ModuleName) AND f.is_signed=1 AND f.is_signature_valid=1))
 THROW 51730,'Installed signature validity is not established.',1;

IF NOT EXISTS(SELECT 1 FROM sys.extended_properties WHERE class=0 AND name=N'S11LegacyPermissionManifest'
 AND CONVERT(nvarchar(64),value) COLLATE Latin1_General_100_BIN2=@ManifestHash)
 THROW 51730,'Exact legacy permission delivery marker required.',1;
SELECT @ManifestHash AS ManifestHash,DB_NAME() AS DatabaseName,
 CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS ServerName,
 N'metadata-only; transaction/proxy/provider/deployment acceptance outstanding' AS Boundary;
