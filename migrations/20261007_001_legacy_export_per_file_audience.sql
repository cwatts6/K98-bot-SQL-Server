/*
MigrationId: 20261007_001_legacy_export_per_file_audience
Purpose: Record approved legacy public editors accurately without weakening S11 pool ACLs
Author: cwatts
CreatedUtc: 2026-10-07
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51726,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51726,'Schema busy.',1;
CREATE TABLE #LegacyAudienceBefore([Role] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AclState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AclCheckedUTC datetime2(0) NULL,CHECK(DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL))));
CREATE TABLE #LegacyAudienceAfter([Role] varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AclState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AclCheckedUTC datetime2(0) NULL,CHECK(DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','public_editor','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL)) AND (AclState <> 'public_editor' OR [Role] = 'output')));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#LegacyAudienceBefore'));
DECLARE @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#LegacyAudienceAfter'));
DECLARE @ObjectID int=OBJECT_ID(N'dbo.ExportAttemptPart',N'U');
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_ExportAttemptPart_Acl' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @ObjectID IS NULL OR @Before IS NULL OR @After IS NULL OR @Actual IS NULL OR NOT (
 (DATALENGTH(@Actual)=DATALENGTH(@Before) AND @Actual COLLATE Latin1_General_100_BIN2=@Before COLLATE Latin1_General_100_BIN2) OR
 (DATALENGTH(@Actual)=DATALENGTH(@After) AND @Actual COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2))
 THROW 51726,'Exact trusted attempt-part ACL preimage required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE dbo.ExportAttemptPart DROP CONSTRAINT CK_ExportAttemptPart_Acl;
 ALTER TABLE dbo.ExportAttemptPart WITH CHECK ADD CONSTRAINT CK_ExportAttemptPart_Acl CHECK(DATALENGTH(AclState) = LEN(AclState) AND AclState IN ('pending','private','public_viewer','public_editor','failed','uncertain') AND ((AclState = 'pending' AND AclCheckedUTC IS NULL) OR (AclState <> 'pending' AND AclCheckedUTC IS NOT NULL)) AND (AclState <> 'public_editor' OR [Role] = 'output'));
END;
IF OBJECT_ID(N'dbo.ExportAttemptPart',N'U')<>@ObjectID OR NOT EXISTS(
 SELECT 1 FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_ExportAttemptPart_Acl'
 AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0
 AND DATALENGTH(definition)=DATALENGTH(@After) AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2)
 THROW 51726,'Corrected trusted legacy ACL postimage required.',1;
DROP TABLE #LegacyAudienceBefore,#LegacyAudienceAfter;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
