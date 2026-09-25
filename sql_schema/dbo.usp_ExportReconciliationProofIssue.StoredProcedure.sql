SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
GO
CREATE PROCEDURE dbo.usp_ExportReconciliationProofIssue
 @SessionID uniqueidentifier,
 @ProofID uniqueidentifier,
 @AccountKey varchar(128),
 @SnapshotHash binary(32),
 @RegistrationHash binary(32),
 @ProofKind varchar(32),
 @Outcome varchar(16),
 @MembershipJson nvarchar(max),
 @EvidenceJson nvarchar(max)
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,'Evidence transition requires its own short transaction.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
   THROW 51700,'Evidence authority role required.',1;
 BEGIN TRANSACTION;
 BEGIN TRY
 DECLARE @LockResult int,@LockKey nvarchar(255);
 SET @LockKey=N'k98-export:'+LOWER(CONVERT(varchar(64),HASHBYTES('SHA2_256',CONVERT(varchar(136),'account:'+@AccountKey)),2));
 EXEC @LockResult=sys.sp_getapplock @Resource=@LockKey,@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @LockResult<0 THROW 51700,'Export admission busy.',1;
 IF NOT EXISTS (SELECT 1 FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK)
 WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open')
 THROW 51700,'Exact open authority session required.',1;

 IF @MembershipJson IS NULL OR ISJSON(@MembershipJson)<>1 OR DATALENGTH(@MembershipJson)>65536
 OR @EvidenceJson IS NULL OR ISJSON(@EvidenceJson)<>1 OR DATALENGTH(@EvidenceJson)>65536
  THROW 51700,'Bounded proof evidence required.',1;
 IF JSON_VALUE(@EvidenceJson,'$.state') IS NULL OR JSON_VALUE(@EvidenceJson,'$.snapshot_hash') IS NULL
 OR JSON_VALUE(@EvidenceJson,'$.state') COLLATE Latin1_General_100_BIN2<>@Outcome COLLATE Latin1_General_100_BIN2
 OR JSON_VALUE(@EvidenceJson,'$.snapshot_hash') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(64),@SnapshotHash,2)) COLLATE Latin1_General_100_BIN2
  THROW 51700,'Proof body differs from immutable outcome/snapshot.',1;
 -- v2 seals the complete registered-file catalogue without truncating retained
 -- history into a bounded stream-ID list. Parent verifies each private journal.
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson))<>4
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key] NOT IN ('version','targets','history','probe'))
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson))<>4
 OR JSON_VALUE(@MembershipJson,'$.version') IS NULL OR JSON_VALUE(@MembershipJson,'$.version')<>'2'
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]='version' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]='targets' AND type=4)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]='history' AND type=5)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson) WHERE [key]='probe' AND type=5)
  THROW 51700,'Versioned complete catalogue membership required.',1;
 DECLARE @Targets TABLE (FileID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY);
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,'$.targets')) NOT BETWEEN 1 AND 17
 OR EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,'$.targets') WHERE type<>1 OR DATALENGTH(value) NOT BETWEEN 6 AND 256
  OR value COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9_-]%')
  THROW 51700,'Bounded exact registered targets required.',1;
 IF EXISTS (SELECT 1 FROM (SELECT value,LAG(value) OVER (ORDER BY CONVERT(int,[key])) AS Previous
  FROM OPENJSON(@MembershipJson,'$.targets')) q WHERE Previous COLLATE Latin1_General_100_BIN2>=value COLLATE Latin1_General_100_BIN2)
  THROW 51700,'Targets must be unique and canonically ordered.',1;
 INSERT @Targets SELECT CONVERT(varchar(128),value) FROM OPENJSON(@MembershipJson,'$.targets');
 IF (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,'$.history'))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,'$.history'))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,'$.history') WHERE [key]='count' AND type=2)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,'$.history') WHERE [key]='sha256' AND type=1)
 OR (SELECT COUNT(*) FROM OPENJSON(@MembershipJson,'$.probe'))<>2
 OR (SELECT COUNT(DISTINCT [key]) FROM OPENJSON(@MembershipJson,'$.probe'))<>2
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,'$.probe') WHERE [key]='stream_id' AND type=1)
 OR NOT EXISTS (SELECT 1 FROM OPENJSON(@MembershipJson,'$.probe') WHERE [key]='version' AND type=2)
  THROW 51700,'Exact history seal and fresh probe identity required.',1;
 DECLARE @ExpectedCount bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,'$.history.count')),
  @HistoryHashText nvarchar(4000)=JSON_VALUE(@MembershipJson,'$.history.sha256'),
  @ProbeID uniqueidentifier=TRY_CONVERT(uniqueidentifier,JSON_VALUE(@MembershipJson,'$.probe.stream_id')),
  @ProbeVersion bigint=TRY_CONVERT(bigint,JSON_VALUE(@MembershipJson,'$.probe.version'));
 IF @ExpectedCount IS NULL OR @ExpectedCount<0 OR @ProbeID IS NULL OR @ProbeVersion IS NULL OR @ProbeVersion<=0
 OR @HistoryHashText IS NULL OR DATALENGTH(@HistoryHashText)<>128 OR @HistoryHashText COLLATE Latin1_General_100_BIN2 LIKE '%[^0-9a-f]%'
 OR DATALENGTH(JSON_VALUE(@MembershipJson,'$.probe.stream_id'))<>72
 OR JSON_VALUE(@MembershipJson,'$.probe.stream_id') COLLATE Latin1_General_100_BIN2<>LOWER(CONVERT(varchar(36),@ProbeID)) COLLATE Latin1_General_100_BIN2
  THROW 51700,'Canonical historical count/hash and probe identity required.',1;
 -- A blank current file is not a creation history. Only sealed managed origins
 -- can enter automatic finality. Old/unproven files remain operator reconciliation.
 IF EXISTS(SELECT 1 FROM @Targets t WHERE NOT EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o
   JOIN dbo.ExportPreparation p ON p.PreparationID=o.PreparationID
   WHERE o.FileID=t.FileID AND o.Stage='eligible' AND p.AccountKey=@AccountKey AND p.State='completed'))
  THROW 51700,'Complete authenticated managed-file origins required.',1;
 DECLARE @Members TABLE (StreamID uniqueidentifier NOT NULL PRIMARY KEY,Version bigint NOT NULL);
 INSERT @Members SELECT s.StreamID,s.Version FROM dbo.ExportExecutionStream s WITH (UPDLOCK,HOLDLOCK)
 WHERE s.AccountKey=@AccountKey AND (EXISTS (SELECT 1 FROM OPENJSON(s.ScopeJson,'$.resources')
  WITH (ResourceKey varchar(256) '$.key') r JOIN @Targets t
  ON r.ResourceKey COLLATE Latin1_General_100_BIN2=('destination:'+t.FileID) COLLATE Latin1_General_100_BIN2)
 OR EXISTS(SELECT 1 FROM dbo.ExportManagedFileOrigin o JOIN @Targets t ON t.FileID=o.FileID
  WHERE o.PreparationID=s.PreparationID AND o.Stage='created'));
 IF NOT EXISTS (SELECT 1 FROM @Members) THROW 51700,'Empty evidence is not proof of historical coverage.',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.State<>'closed' OR s.ActiveAccountKey IS NOT NULL OR s.ClosureHash IS NULL OR s.EventDigest IS NULL)
  THROW 51700,'Exact closed request-stream membership required.',1;
 DECLARE @CatalogueHash binary(32)=HASHBYTES('SHA2_256',CONVERT(varbinary(max),'K98-S11-CATALOGUE-1')),
  @CatalogueCount bigint=0,@CatalogueID uniqueidentifier,@CatalogueVersion bigint,@CatalogueEvents binary(32);
 DECLARE CatalogueRows CURSOR LOCAL FAST_FORWARD FOR
 SELECT s.StreamID,s.Version,s.EventDigest FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
 WHERE s.StreamID<>@ProbeID ORDER BY LOWER(CONVERT(varchar(36),s.StreamID)) COLLATE Latin1_General_100_BIN2;
 OPEN CatalogueRows;
 FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 WHILE @@FETCH_STATUS=0
 BEGIN
  SET @CatalogueHash=HASHBYTES('SHA2_256',@CatalogueHash+CONVERT(varbinary(max),LOWER(CONVERT(varchar(36),@CatalogueID)))
   +CONVERT(varbinary(max),':'+CONVERT(varchar(20),@CatalogueVersion)+':')+@CatalogueEvents);
  SET @CatalogueCount=@CatalogueCount+1;
  FETCH NEXT FROM CatalogueRows INTO @CatalogueID,@CatalogueVersion,@CatalogueEvents;
 END;
 CLOSE CatalogueRows;
 DEALLOCATE CatalogueRows;
 IF @CatalogueCount<>@ExpectedCount OR @CatalogueHash<>CONVERT(binary(32),@HistoryHashText,2)
  THROW 51700,'Historical writer catalogue changed around the fresh probe.',1;
 IF NOT EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportExecutionStream s ON s.StreamID=m.StreamID
   WHERE s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose='probe'
   AND s.SnapshotHash=@SnapshotHash AND s.RegistrationHash=@RegistrationHash
   AND EXISTS (SELECT 1 FROM dbo.ExportProviderRequest r JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
     WHERE r.StreamID=s.StreamID AND r.RequestKind='read' AND e.State='succeeded'))
  THROW 51700,'Fresh snapshot-bound closed probe required.',1;
 IF EXISTS (SELECT 1 FROM @Members m JOIN dbo.ExportProviderRequest r ON r.StreamID=m.StreamID
   WHERE NOT EXISTS (SELECT 1 FROM dbo.ExportProviderRequestEvent e WHERE e.RequestID=r.RequestID AND e.State IN ('succeeded','not_sent')))
  THROW 51700,'Request gaps or unknown outcomes cannot become proof.',1;
 -- Older successful jobs stay in the complete catalogue, but do not imply that
 -- this publication dispatched a mutation. Cover every stream of its exact job,
 -- including former nested owners, even outside the current registered target set.
 DECLARE @SubjectJob uniqueidentifier=(SELECT JobID FROM dbo.ExportExecutionStream WHERE StreamID=@ProbeID);
 IF @Outcome='absent' AND (@ProofKind<>'publication' OR @SubjectJob IS NULL)
  THROW 51700,'Absence requires an exact publication-job probe.',1;
 IF @Outcome='absent' AND EXISTS (SELECT 1 FROM dbo.ExportExecutionStream s
   JOIN dbo.ExportProviderRequest r ON r.StreamID=s.StreamID
   JOIN dbo.ExportProviderRequestEvent e ON e.RequestID=r.RequestID
   WHERE s.AccountKey=@AccountKey AND s.JobID=@SubjectJob AND r.RequestKind='mutation' AND e.State='dispatch_intent')
  THROW 51700,'Dispatched mutation cannot support absence proof.',1;
 IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE ActiveAccountKey=@AccountKey)
  THROW 51700,'A live provider writer/probe prevents proof issue.',1;
 -- Parent authority must attest COMPLETE historical writer coverage and exact
 -- method-specific readback; SQL does not infer provider truth from row presence.
 INSERT dbo.ExportReconciliationProof VALUES (@ProofID,@SessionID,@AccountKey,@SnapshotHash,@RegistrationHash,@ProofKind,@Outcome,
  HASHBYTES('SHA2_256',CONVERT(varbinary(max),@MembershipJson)),@MembershipJson,@EvidenceJson,SYSUTCDATETIME());
 SELECT * FROM dbo.ExportReconciliationProof WHERE ProofID=@ProofID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
