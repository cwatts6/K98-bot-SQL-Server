/*
MigrationId: 20261006_002_initial_output_slot_disposition
Purpose: Permit first verified-empty registration without inventing a clear event
Author: cwatts
CreatedUtc: 2026-10-06
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
/* First registration requires separately verified manual enrollment. Only an
   unowned/unassigned epoch-1 version-1 fence-0 slot may lack a disposition.
   Existing/reused slots keep their original clear/assignment/history rules. */
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51725,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int;
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51725,'Schema busy.',1;
CREATE TABLE #InitialSlotBefore(LastDispositionID uniqueidentifier NULL,LastAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,LastDispositionVersion bigint NULL,State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AssignmentID uniqueidentifier NULL,OwnerID uniqueidentifier NULL,Fence bigint NOT NULL,Version bigint NOT NULL,Epoch bigint NOT NULL,CHECK((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire')))));
CREATE TABLE #InitialSlotAfter(LastDispositionID uniqueidentifier NULL,LastAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,LastDispositionVersion bigint NULL,State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AssignmentID uniqueidentifier NULL,OwnerID uniqueidentifier NULL,Fence bigint NOT NULL,Version bigint NOT NULL,Epoch bigint NOT NULL,CHECK(((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire'))) OR (LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'free' AND AssignmentID IS NULL AND OwnerID IS NULL AND Fence = 0 AND Version = 1 AND Epoch = 1))));
DECLARE @Before nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#InitialSlotBefore'));
DECLARE @After nvarchar(max)=(SELECT definition FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#InitialSlotAfter'));
DECLARE @ObjectID int=OBJECT_ID(N'KVK.SourceOutputSlot',N'U');
DECLARE @Actual nvarchar(max)=(SELECT definition FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_SourceOutputSlot_Disposition' AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0);
IF @ObjectID IS NULL OR @Before IS NULL OR @After IS NULL OR @Actual IS NULL OR NOT (
 (DATALENGTH(@Actual)=DATALENGTH(@Before) AND @Actual COLLATE Latin1_General_100_BIN2=@Before COLLATE Latin1_General_100_BIN2) OR
 (DATALENGTH(@Actual)=DATALENGTH(@After) AND @Actual COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2))
 THROW 51725,'Exact trusted slot disposition constraint required.',1;
IF @Actual COLLATE Latin1_General_100_BIN2<>@After COLLATE Latin1_General_100_BIN2
BEGIN
 ALTER TABLE KVK.SourceOutputSlot DROP CONSTRAINT CK_SourceOutputSlot_Disposition;
 ALTER TABLE KVK.SourceOutputSlot WITH CHECK ADD CONSTRAINT CK_SourceOutputSlot_Disposition CHECK(((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire'))) OR (LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'free' AND AssignmentID IS NULL AND OwnerID IS NULL AND Fence = 0 AND Version = 1 AND Epoch = 1)));
END;
IF OBJECT_ID(N'KVK.SourceOutputSlot',N'U')<>@ObjectID OR NOT EXISTS(
 SELECT 1 FROM sys.check_constraints WHERE parent_object_id=@ObjectID AND name=N'CK_SourceOutputSlot_Disposition'
 AND is_disabled=0 AND is_not_trusted=0 AND is_not_for_replication=0
 AND DATALENGTH(definition)=DATALENGTH(@After) AND definition COLLATE Latin1_General_100_BIN2=@After COLLATE Latin1_General_100_BIN2)
 THROW 51725,'Corrected trusted initial-slot postimage required.',1;
DROP TABLE #InitialSlotBefore,#InitialSlotAfter;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
