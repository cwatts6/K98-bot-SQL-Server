/*
MigrationId: 20261001_008_manual_file_id_constraint
Purpose: Align manual origin FileID constraint with the corrected literal hyphen class
Author: cwatts
CreatedUtc: 2026-10-01
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
IF @@TRANCOUNT<>0 THROW 51723,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51723,'Schema busy.',1;
CREATE TABLE #Before(FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,Ordinal int NOT NULL,
 CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16));
CREATE TABLE #After(FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,Ordinal int NOT NULL,
 CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#Before'));
DECLARE @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#After'));
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportManualFileOrigin',N'U') AND name=N'CK_ExportManualFileOrigin_Identity' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @Before IS NULL OR @After IS NULL OR @Actual IS NULL OR NOT (
 (DATALENGTH(@Actual)=DATALENGTH(@Before) AND @Actual COLLATE Latin1_General_100_BIN2=@Before COLLATE Latin1_General_100_BIN2) OR
 (DATALENGTH(@Actual)=DATALENGTH(@After) AND @Actual COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2))
 THROW 51723,'Exact trusted manual identity constraint required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE dbo.ExportManualFileOrigin DROP CONSTRAINT CK_ExportManualFileOrigin_Identity;
 ALTER TABLE dbo.ExportManualFileOrigin WITH CHECK ADD CONSTRAINT CK_ExportManualFileOrigin_Identity CHECK(DATALENGTH(FileID) BETWEEN 3 AND 128 AND DATALENGTH(FileID)=LEN(FileID) AND FileID NOT LIKE '%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2 AND Ordinal BETWEEN 0 AND 16);
END;
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportManualFileOrigin',N'U') AND name=N'CK_ExportManualFileOrigin_Identity' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0 AND DATALENGTH(definition)=DATALENGTH(@After) AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2)
 THROW 51723,'Corrected trusted constraint postimage required.',1;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
