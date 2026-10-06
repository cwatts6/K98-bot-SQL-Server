/*
MigrationId: 20261006_001_source_output_file_id_constraint
Purpose: Admit literal hyphens and underscores in registered Google file IDs
Author: cwatts
CreatedUtc: 2026-10-06
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51724,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51724,'Schema busy.',1;
CREATE TABLE #OutputFileIDBefore(FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,CHECK(DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2));
CREATE TABLE #OutputFileIDAfter(FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,CHECK(DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#OutputFileIDBefore'));
DECLARE @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#OutputFileIDAfter'));
DECLARE @ObjectID int=OBJECT_ID(N'KVK.SourceOutputFile',N'U');
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_SourceOutputFile_Identity' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @ObjectID IS NULL OR @Before IS NULL OR @After IS NULL OR @Actual IS NULL OR NOT (
 (DATALENGTH(@Actual)=DATALENGTH(@Before) AND @Actual COLLATE Latin1_General_100_BIN2=@Before COLLATE Latin1_General_100_BIN2) OR
 (DATALENGTH(@Actual)=DATALENGTH(@After) AND @Actual COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2))
 THROW 51724,'Exact trusted output-file identity constraint required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE KVK.SourceOutputFile DROP CONSTRAINT CK_SourceOutputFile_Identity;
 ALTER TABLE KVK.SourceOutputFile WITH CHECK ADD CONSTRAINT CK_SourceOutputFile_Identity CHECK(DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2);
END;
IF OBJECT_ID(N'KVK.SourceOutputFile',N'U')<>@ObjectID OR NOT EXISTS(
 SELECT 1 FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_SourceOutputFile_Identity'
 AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0
 AND DATALENGTH(definition)=DATALENGTH(@After) AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2)
 THROW 51724,'Corrected trusted output-file constraint postimage required.',1;
DROP TABLE #OutputFileIDBefore,#OutputFileIDAfter;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
