-- S10A authored validation only. No SQL execution is authorized by implementation approval.
-- Requires a separately approved NEW K98_S10A_Disposable_* database and exact server,
-- plus empty S8A/S8B prerequisite snapshots. Never rerun predecessor migrations/tests.
-- Caller supplies SESSION_CONTEXT keys S10A_AUTHORIZED=1, S10A_SERVER, S10A_DATABASE,
-- S10A_CASE: install, constraints, partial or drift. Each case has its own exact approval.
-- #S10AMigrationInput(SqlText nvarchar(max), ExpectedUtf16Hash binary(32),
-- BackupEvidence nvarchar(1024), RestoreEvidence nvarchar(1024)): one reviewed bound row.
-- Record UTF-8 file SHA256 independently; no SQLCMD, network reads or runner defaults.
-- All case-created schema/data rolls back. Retain the database and external evidence.
-- These sequential structural cases do not prove worker concurrency or provider safety.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT <> 0 THROW 51900, 'S10A fixture refuses an ambient transaction.', 1;
IF COALESCE(TRY_CONVERT(int,SESSION_CONTEXT(N'S10A_AUTHORIZED')),0) <> 1
 OR SESSION_CONTEXT(N'S10A_SERVER') IS NULL OR SESSION_CONTEXT(N'S10A_DATABASE') IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'S10A_SERVER')) COLLATE Latin1_General_100_BIN2 <> CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'S10A_DATABASE')) COLLATE Latin1_General_100_BIN2 <> DB_NAME() COLLATE Latin1_General_100_BIN2
 OR DB_ID() <= 4 OR DB_NAME() NOT LIKE N'K98[_]S10A[_]Disposable[_]%'
    THROW 51900, 'Exact new S10A disposable target authorization required.', 1;
DECLARE @Case varchar(32)=CONVERT(varchar(32),SESSION_CONTEXT(N'S10A_CASE'));
IF @Case IS NULL OR @Case COLLATE Latin1_General_100_BIN2 NOT IN ('install','constraints','partial','drift') OR DATALENGTH(@Case)<>LEN(@Case)
    THROW 51900, 'Exact S10A case required.', 1;
IF OBJECT_ID(N'tempdb..#S10AMigrationInput') IS NULL THROW 51900, 'Reviewed migration and backup/restore evidence required.', 1;
IF (SELECT COUNT_BIG(*) FROM #S10AMigrationInput)<>1 OR EXISTS
 (SELECT 1 FROM #S10AMigrationInput WHERE SqlText IS NULL OR ExpectedUtf16Hash IS NULL
 OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),SqlText))<>ExpectedUtf16Hash
 OR BackupEvidence IS NULL OR LEN(BackupEvidence)=0 OR RestoreEvidence IS NULL OR LEN(RestoreEvidence)=0)
    THROW 51900, 'Reviewed S10A migration bytes or safety evidence invalid.', 1;
DECLARE @Migration nvarchar(max)=(SELECT SqlText FROM #S10AMigrationInput);
DECLARE @WasXactAbort bit=CASE WHEN (16384 & @@OPTIONS)=16384 THEN 1 ELSE 0 END;
DECLARE @ExpectedObjects int=CASE WHEN @Case IN ('constraints','drift') THEN 6 ELSE 0 END;
IF (SELECT COUNT(*) FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN
 ('ExportJob','ExportResource','ExportJobResource','ExportRequestBudget','ExportAttempt','ExportAttemptPart'))<>@ExpectedObjects
    THROW 51900, 'Fixture requires the exact initial S10A object state.', 1;
IF EXISTS (SELECT 1 FROM KVK.SeasonSource) OR EXISTS (SELECT 1 FROM KVK.SourceExportIntent)
 OR EXISTS (SELECT 1 FROM KVK.SourceDelivery) OR EXISTS (SELECT 1 FROM KVK.SourcePublication)
    THROW 51900, 'Fixture requires empty prerequisite state; retained histories are not targets.', 1;
IF @ExpectedObjects=6
BEGIN
    EXEC sys.sp_executesql N'IF EXISTS (SELECT 1 FROM dbo.ExportJob) OR EXISTS (SELECT 1 FROM dbo.ExportAttempt)
        OR EXISTS (SELECT 1 FROM dbo.ExportResource) OR EXISTS (SELECT 1 FROM dbo.ExportRequestBudget)
        OR EXISTS (SELECT 1 FROM dbo.ExportJobResource) OR EXISTS (SELECT 1 FROM dbo.ExportAttemptPart)
        THROW 51900, ''S10A fixture requires empty export tables.'', 1;';
END;
BEGIN TRANSACTION;
BEGIN TRY
    IF @Case='partial'
    BEGIN
        EXEC sys.sp_executesql N'CREATE TABLE dbo.ExportJob (JobID uniqueidentifier NOT NULL);';
        BEGIN TRY
            EXEC sys.sp_executesql @Migration;
            THROW 51901, 'Partial installation was accepted.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>51000 OR ERROR_MESSAGE() NOT LIKE 'Partial S10A installation:%' THROW;
        END CATCH;
        -- Expected THROW/XACT_ABORT can doom this transaction; inspect then roll back.
        IF OBJECT_ID(N'dbo.ExportAttempt') IS NOT NULL OR COL_LENGTH(N'dbo.ExportJob',N'ConsumerKind') IS NOT NULL
            THROW 51901, 'Partial rejection changed the fixture schema.', 1;
    END
    ELSE IF @Case='drift'
    BEGIN
        EXEC sys.sp_executesql N'ALTER TABLE dbo.ExportJob NOCHECK CONSTRAINT CK_ExportJob_State;';
        BEGIN TRY
            EXEC sys.sp_executesql @Migration;
            THROW 51901, 'Untrusted/disabled CHECK was accepted.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>51000 OR ERROR_MESSAGE() NOT LIKE 'S10A check constraint shape conflict%' THROW;
        END CATCH;
    END
    ELSE
    BEGIN
        EXEC sys.sp_executesql @Migration;
        EXEC sys.sp_executesql @Migration;
        -- Constraint DML is compiled after installation, in the same rollback transaction.
        DECLARE @Checks nvarchar(max)=N'SET XACT_ABORT OFF;
SET ANSI_WARNINGS ON;
DECLARE @Utc datetime2(0)=''2000-01-01'', @Choice uniqueidentifier=NEWID(), @Intent uniqueidentifier=NEWID(),
 @New uniqueidentifier=NEWID(), @Legacy uniqueidentifier=NEWID(), @Scan uniqueidentifier=NEWID(),
 @Owner uniqueidentifier=NEWID(), @Attempt uniqueidentifier=NEWID();
INSERT KVK.SeasonSource VALUES (2147483400,''snapshot_report_v1'',@Choice,N''synthetic'',@Utc,N''S10A fixture'',N''{"synthetic":true}'',''open'',1);
INSERT KVK.SourceExportIntent VALUES (@Intent,''snapshot_report_v1'',2147483400,@Choice,1,CONVERT(binary(32),0x01),''s10a-fixture'',''waiting_destination'',@Utc,NULL);
INSERT dbo.ExportJob (JobID,ConsumerKind,SourceKey,IntentID,AccountKey,DestinationSetHash,InputHash,SpoolKey,SpoolBytes,StorageOwner,KVK_NO,PoolEpoch,RepairID,EnqueueSequence,State,OwnerID,Fence,Version,CreatedUTC,UpdatedUTC,SupersededByJobID,Actor,Reason,ProvenanceJson)
VALUES (@New,''new_source'',''snapshot_report_v1'',@Intent,''synthetic'',0x01,0x01,NULL,NULL,NULL,2147483400,1,NULL,1,''running'',@Owner,1,1,@Utc,@Utc,NULL,N''synthetic'',N''fixture'',N''{}''),
 (@Legacy,''all_kvk'',NULL,NULL,''synthetic'',0x02,0x02,''opaque_spool'',1,''storage_a'',2147483400,NULL,NULL,2,''ready'',NULL,0,1,@Utc,@Utc,NULL,N''synthetic'',N''fixture'',N''{}''),
 (@Scan,''scan_data'',NULL,NULL,''synthetic'',0x03,0x03,''opaque_daily'',1,''storage_a'',NULL,NULL,NULL,3,''ready'',NULL,0,1,@Utc,@Utc,NULL,N''synthetic'',N''fixture'',N''{}'');
INSERT dbo.ExportResource VALUES (''account:synthetic'',''account'',NULL,NULL,0,NULL,1);
INSERT dbo.ExportJobResource VALUES (@New,''account:synthetic'');
UPDATE dbo.ExportResource SET ActiveJobID=@New,OwnerID=@Owner,Fence=1 WHERE ResourceKey=''account:synthetic'';
INSERT dbo.ExportRequestBudget VALUES (''synthetic'',''google_request'',''2000-01-01T00:00:02.100'',''2000-01-01T00:00:03.125'',2100,1,1);
IF NOT EXISTS (SELECT 1 FROM dbo.ExportRequestBudget WHERE AccountKey=''synthetic'' AND DATEPART(millisecond,NextAllowedUTC)=100 AND DATEPART(millisecond,CooldownUntilUTC)=125)
 THROW 51901,''Budget millisecond precision lost.'',1;
INSERT dbo.ExportAttempt (AttemptID,JobID,ConsumerKind,AttemptNo,OwnerID,Fence,Epoch,Phase,RemoteSequence,Version,CreatedUTC,UpdatedUTC,ManifestHash,ManifestJson,PartCount)
VALUES (@Attempt,@New,''new_source'',1,@Owner,1,1,''private_started'',1,1,@Utc,@Utc,0x01,N''{}'',2);
INSERT dbo.ExportAttemptPart VALUES (@Attempt,1,2,N''synthetic-file'',''generation'',0x01,1,1,1,''pending'',NULL,''pending'',NULL,''none'',NULL,NULL,NULL,1);
DECLARE @Cases TABLE (CaseNo int IDENTITY(1,1), Label nvarchar(128), Statement nvarchar(max), ExpectedError int);
INSERT @Cases (Label,Statement,ExpectedError) VALUES
(N''null replay identity duplicate'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',2627),
(N''distinct explicit repair'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''distinct new-source epoch'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, 2, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',0),
(N''distinct account'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, ''''other-account'''', DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''distinct destination'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, CONVERT(binary(32),0x77), InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''consumer case rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ''''ALL_KVK'''', SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''consumer trailing blank rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ''''all_kvk '''', SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''unknown state rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''blocked'''', OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''running without owner rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''running'''', OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''uncertain without owner rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''uncertain'''', OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''zero owner fence rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''running'''', NEWID(), Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''partial spool tuple rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, NULL, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''zero spool bytes rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, 0, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''spool path rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, ''''../unsafe'''', SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''empty account rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, '''''''', DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''account trailing blank rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, ''''account '''', DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''account maximum length'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, REPLICATE(''''a'''',128), DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''account over maximum length'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, REPLICATE(''''a'''',129), DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',8152),
(N''spool maximum length'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, REPLICATE(''''s'''',128), SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''spool over maximum length'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, REPLICATE(''''s'''',129), SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',8152),
(N''JSON exact byte limit'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, N''''{"x":"''''+REPLICATE(CONVERT(nvarchar(max),N''''x''''),32760)+N''''"}'''' FROM dbo.ExportJob WHERE JobID=@Legacy;'',0),
(N''null new-source intent rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, NULL, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',547),
(N''missing intent FK rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, NEWID(), AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',547),
(N''cross-season intent rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, 2147483401, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',547),
(N''legacy pool epoch rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, 1, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''scan season rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, 1, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Scan;'',547),
(N''zero enqueue ticket rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), 0, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''zero version rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, 0, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''invalid JSON rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, N''''invalid'''' FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''oversized JSON rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, N''''{"x":"''''+REPLICATE(CONVERT(nvarchar(max),N''''x''''),32768)+N''''"}'''' FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''backward time rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, ''''1999-12-31'''', SupersededByJobID, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''legacy coalescing rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''coalesced'''', OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, @New, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@Legacy;'',547),
(N''new-source coalescing retained ticket'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, CONVERT(binary(32),0x99), SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, ''''coalesced'''', NULL, 0, Version, CreatedUTC, UpdatedUTC, @New, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',0),
(N''cross-destination supersession rejected'',N''INSERT dbo.ExportJob (JobID, ConsumerKind, SourceKey, IntentID, AccountKey, DestinationSetHash, InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, RepairID, EnqueueSequence, State, OwnerID, Fence, Version, CreatedUTC, UpdatedUTC, SupersededByJobID, Actor, Reason, ProvenanceJson) SELECT NEWID(), ConsumerKind, SourceKey, IntentID, AccountKey, CONVERT(binary(32),0x99), InputHash, SpoolKey, SpoolBytes, StorageOwner, KVK_NO, PoolEpoch, NEWID(), EnqueueSequence, ''''coalesced'''', NULL, 0, Version, CreatedUTC, UpdatedUTC, @New, Actor, Reason, ProvenanceJson FROM dbo.ExportJob WHERE JobID=@New;'',547),
(N''duplicate resource membership'',N''INSERT dbo.ExportJobResource VALUES (@New,''''account:synthetic'''');'',2627),
(N''missing resource FK'',N''INSERT dbo.ExportJobResource VALUES (@New,''''missing'''');'',547),
(N''undeclared active resource'',N''UPDATE dbo.ExportResource SET ActiveJobID=@Legacy,OwnerID=@Owner,Fence=1 WHERE ResourceKey=''''account:synthetic'''';'',547),
(N''partial resource owner'',N''UPDATE dbo.ExportResource SET OwnerID=NULL WHERE ResourceKey=''''account:synthetic'''';'',547),
(N''resource stale CAS'',N''UPDATE dbo.ExportResource SET Version=Version+1 WHERE ResourceKey=''''account:synthetic'''' AND Version=999; IF @@ROWCOUNT<>0 THROW 51901,''''Stale CAS succeeded'''',1;'',0),
(N''budget duplicate key'',N''INSERT dbo.ExportRequestBudget VALUES (''''synthetic'''',''''google_request'''',@Utc,NULL,2100,1,1);'',2627),
(N''budget kind allowlist'',N''INSERT dbo.ExportRequestBudget VALUES (''''synthetic'''',''''unregistered'''',@Utc,NULL,2100,1,1);'',547),
(N''budget zero interval'',N''UPDATE dbo.ExportRequestBudget SET IntervalMilliseconds=0 WHERE AccountKey=''''synthetic'''';'',547),
(N''budget zero policy version'',N''UPDATE dbo.ExportRequestBudget SET PolicyVersion=0 WHERE AccountKey=''''synthetic'''';'',547),
(N''attempt duplicate sequence'',N''INSERT dbo.ExportAttempt (AttemptID,JobID,ConsumerKind,AttemptNo,OwnerID,Fence,Epoch,Phase,RemoteSequence,Version,CreatedUTC,UpdatedUTC,ManifestHash,ManifestJson,PartCount) VALUES (NEWID(),@New,''''new_source'''',1,@Owner,1,1,''''private_started'''',1,1,@Utc,@Utc,0x01,N''''{}'''',2);'',2627),
(N''attempt wrong consumer'',N''UPDATE dbo.ExportAttempt SET ConsumerKind=''''all_kvk'''',Epoch=NULL WHERE AttemptID=@Attempt;'',547),
(N''attempt wrong epoch'',N''UPDATE dbo.ExportAttempt SET Epoch=2 WHERE AttemptID=@Attempt;'',547),
(N''attempt null epoch'',N''UPDATE dbo.ExportAttempt SET Epoch=NULL WHERE AttemptID=@Attempt;'',547),
(N''attempt unknown phase'',N''UPDATE dbo.ExportAttempt SET Phase=''''claimed'''' WHERE AttemptID=@Attempt;'',547),
(N''attempt verified evidence'',N''UPDATE dbo.ExportAttempt SET Phase=''''verified'''',VerifiedUTC=@Utc WHERE AttemptID=@Attempt;'',0),
(N''attempt publication pending evidence'',N''UPDATE dbo.ExportAttempt SET Phase=''''publication_pending'''',VerifiedUTC=@Utc WHERE AttemptID=@Attempt;'',0),
(N''attempt published evidence'',N''UPDATE dbo.ExportAttempt SET Phase=''''published'''',VerifiedUTC=@Utc,PublishedUTC=@Utc,ReceiptJson=N''''{}'''' WHERE AttemptID=@Attempt;'',0),
(N''attempt retired retained receipt'',N''UPDATE dbo.ExportAttempt SET Phase=''''retired'''',VerifiedUTC=@Utc,PublishedUTC=@Utc,ReceiptJson=N''''{}'''' WHERE AttemptID=@Attempt;'',0),
(N''attempt failed evidence retained'',N''UPDATE dbo.ExportAttempt SET Phase=''''failed'''',ReceiptJson=N''''{}'''' WHERE AttemptID=@Attempt;'',0),
(N''publication requires verification'',N''UPDATE dbo.ExportAttempt SET Phase=''''published'''' WHERE AttemptID=@Attempt;'',547),
(N''attempt partial legacy tuple'',N''UPDATE dbo.ExportAttempt SET LegacyPublicationID=NEWID() WHERE AttemptID=@Attempt;'',547),
(N''attempt missing legacy receipt FK'',N''UPDATE dbo.ExportAttempt SET LegacyPublicationID=NEWID(),LegacySourceKey=''''snapshot_report_v1'''',LegacyKVK_NO=2147483400,LegacyPeriodID=NEWID(),LegacyDestinationKind=''''sheets'''',LegacyDestinationID=N''''synthetic-file'''' WHERE AttemptID=@Attempt;'',547),
(N''attempt oversized receipt'',N''UPDATE dbo.ExportAttempt SET ReceiptJson=N''''{"x":"''''+REPLICATE(CONVERT(nvarchar(max),N''''x''''),32768)+N''''"}'''' WHERE AttemptID=@Attempt;'',547),
(N''part count upper bound'',N''UPDATE dbo.ExportAttempt SET PartCount=1025 WHERE AttemptID=@Attempt;'',547),
(N''part duplicate number'',N''INSERT dbo.ExportAttemptPart SELECT AttemptID,PartNo,PartCount,N''''other-file'''',[Role],ManifestHash,GridCount,[RowCount],CellCount,VerificationState,VerifiedUTC,AclState,AclCheckedUTC,QuarantineState,QuarantinedUTC,QuarantineReason,EvidenceJson,Version FROM dbo.ExportAttemptPart WHERE AttemptID=@Attempt AND PartNo=1;'',2627),
(N''part duplicate file'',N''INSERT dbo.ExportAttemptPart SELECT AttemptID,2,PartCount,FileID,[Role],ManifestHash,GridCount,[RowCount],CellCount,VerificationState,VerifiedUTC,AclState,AclCheckedUTC,QuarantineState,QuarantinedUTC,QuarantineReason,EvidenceJson,Version FROM dbo.ExportAttemptPart WHERE AttemptID=@Attempt AND PartNo=1;'',2627),
(N''part case-distinct identity'',N''INSERT dbo.ExportAttemptPart SELECT AttemptID,2,PartCount,N''''SYNTHETIC-FILE'''',[Role],ManifestHash,GridCount,[RowCount],CellCount,VerificationState,VerifiedUTC,AclState,AclCheckedUTC,QuarantineState,QuarantinedUTC,QuarantineReason,EvidenceJson,Version FROM dbo.ExportAttemptPart WHERE AttemptID=@Attempt AND PartNo=1;'',0),
(N''part number beyond declared manifest'',N''UPDATE dbo.ExportAttemptPart SET PartNo=3 WHERE AttemptID=@Attempt;'',547),
(N''part mismatched declared count FK'',N''UPDATE dbo.ExportAttemptPart SET PartCount=3 WHERE AttemptID=@Attempt;'',547),
(N''part unknown role'',N''UPDATE dbo.ExportAttemptPart SET [Role]=''''unknown'''' WHERE AttemptID=@Attempt;'',547),
(N''part negative count'',N''UPDATE dbo.ExportAttemptPart SET CellCount=-1 WHERE AttemptID=@Attempt;'',547),
(N''part verified requires time'',N''UPDATE dbo.ExportAttemptPart SET VerificationState=''''verified'''' WHERE AttemptID=@Attempt;'',547),
(N''part ACL requires evidence time'',N''UPDATE dbo.ExportAttemptPart SET AclState=''''public_viewer'''' WHERE AttemptID=@Attempt;'',547),
(N''part quarantine requires reason'',N''UPDATE dbo.ExportAttemptPart SET QuarantineState=''''quarantined'''',QuarantinedUTC=@Utc WHERE AttemptID=@Attempt;'',547),
(N''part invalid evidence JSON'',N''UPDATE dbo.ExportAttemptPart SET EvidenceJson=N''''not json'''' WHERE AttemptID=@Attempt;'',547),
(N''file maximum length'',N''UPDATE dbo.ExportAttemptPart SET FileID=REPLICATE(N''''f'''',128) WHERE AttemptID=@Attempt;'',0),
(N''file over maximum length'',N''UPDATE dbo.ExportAttemptPart SET FileID=REPLICATE(N''''f'''',129) WHERE AttemptID=@Attempt;'',8152),
(N''part verified timestamp'',N''UPDATE dbo.ExportAttemptPart SET VerificationState=''''verified'''',VerifiedUTC=@Utc WHERE AttemptID=@Attempt;'',0),
(N''part private ACL evidence'',N''UPDATE dbo.ExportAttemptPart SET AclState=''''private'''',AclCheckedUTC=@Utc WHERE AttemptID=@Attempt;'',0),
(N''part public Viewer ACL evidence'',N''UPDATE dbo.ExportAttemptPart SET AclState=''''public_viewer'''',AclCheckedUTC=@Utc WHERE AttemptID=@Attempt;'',0),
(N''job deletion retains references'',N''DELETE FROM dbo.ExportJob WHERE JobID=@New;'',547),
(N''attempt deletion retains parts'',N''DELETE FROM dbo.ExportAttempt WHERE AttemptID=@Attempt;'',547);
DECLARE @N int=1,@Label nvarchar(128),@Statement nvarchar(max),@ExpectedError int,@Caught int,@Message nvarchar(2048);
WHILE @N<=(SELECT COUNT(*) FROM @Cases)
BEGIN
 SELECT @Label=Label,@Statement=Statement,@ExpectedError=ExpectedError FROM @Cases WHERE CaseNo=@N;
 SET @Caught=0;
 SAVE TRANSACTION S10ACase;
 BEGIN TRY
  EXEC sys.sp_executesql @Statement,N''@Legacy uniqueidentifier,@New uniqueidentifier,@Scan uniqueidentifier,@Owner uniqueidentifier,@Attempt uniqueidentifier,@Utc datetime2(0)'',@Legacy,@New,@Scan,@Owner,@Attempt,@Utc;
 END TRY
 BEGIN CATCH
  SET @Caught=ERROR_NUMBER();
  IF XACT_STATE()<>1 THROW;
 END CATCH;
 ROLLBACK TRANSACTION S10ACase;
 -- SQL Server versions/settings emit either 8152 or verbose 2628 for truncation.
 IF @Caught<>@ExpectedError AND NOT (@ExpectedError=8152 AND @Caught=2628)
 BEGIN
  SET @Message=CONCAT(@Label,N'': expected error '',@ExpectedError,N'', received '',@Caught);
  THROW 51901,@Message,1;
 END;
 SET @N+=1;
END;
-- Retain an ambiguous attempt and resource; rerun must not reset any of their bytes.
UPDATE dbo.ExportJob SET State=''uncertain'' WHERE JobID=@New;
UPDATE dbo.ExportResource SET BlockedReason=N''pointer result uncertain'' WHERE ResourceKey=''account:synthetic'';
UPDATE dbo.ExportAttempt SET Phase=''uncertain'',ReceiptJson=N''{"uncertain":true,"retained":"original"}'' WHERE AttemptID=@Attempt;
UPDATE dbo.ExportAttemptPart SET QuarantineState=''quarantined'',QuarantinedUTC=@Utc,QuarantineReason=N''worker not proven stopped'' WHERE AttemptID=@Attempt;
DECLARE @Before nvarchar(max)=(SELECT * FROM dbo.ExportJob ORDER BY JobID FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportResource ORDER BY ResourceKey FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportAttempt ORDER BY AttemptID FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportAttemptPart ORDER BY AttemptID,PartNo FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM KVK.SourceExportIntent ORDER BY IntentID FOR JSON PATH,INCLUDE_NULL_VALUES);
EXEC sys.sp_executesql @Migration;
DECLARE @After nvarchar(max)=(SELECT * FROM dbo.ExportJob ORDER BY JobID FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportResource ORDER BY ResourceKey FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportAttempt ORDER BY AttemptID FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM dbo.ExportAttemptPart ORDER BY AttemptID,PartNo FOR JSON PATH,INCLUDE_NULL_VALUES)
 +(SELECT * FROM KVK.SourceExportIntent ORDER BY IntentID FOR JSON PATH,INCLUDE_NULL_VALUES);
IF CONVERT(varbinary(max),@Before)<>CONVERT(varbinary(max),@After)
 THROW 51901,''Rerun changed retained generation/uncertainty evidence.'',1;
SELECT COUNT(*) AS StructuralCasesPassed FROM @Cases;
';
        EXEC sys.sp_executesql @Checks, N'@Migration nvarchar(max)', @Migration;
    END;
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @WasXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;
IF @WasXactAbort=1 SET XACT_ABORT ON; ELSE SET XACT_ABORT OFF;
IF (SELECT COUNT(*) FROM sys.objects WHERE schema_id=SCHEMA_ID(N'dbo') AND name IN
 ('ExportJob','ExportResource','ExportJobResource','ExportRequestBudget','ExportAttempt','ExportAttemptPart'))<>@ExpectedObjects
    THROW 51901, 'Fixture schema survived rollback.', 1;
IF EXISTS (SELECT 1 FROM KVK.SeasonSource) OR EXISTS (SELECT 1 FROM KVK.SourceExportIntent)
    THROW 51901, 'Synthetic prerequisite rows survived rollback.', 1;
IF @ExpectedObjects=6
    EXEC sys.sp_executesql N'IF EXISTS (SELECT 1 FROM dbo.ExportJob) OR EXISTS (SELECT 1 FROM dbo.ExportAttempt)
        OR EXISTS (SELECT 1 FROM dbo.ExportResource) OR EXISTS (SELECT 1 FROM dbo.ExportRequestBudget)
        OR EXISTS (SELECT 1 FROM dbo.ExportJobResource) OR EXISTS (SELECT 1 FROM dbo.ExportAttemptPart)
        THROW 51901, ''Synthetic export rows survived rollback.'', 1;';
SELECT @Case AS PassedCase, 'rollback_only_no_provider_or_worker_evidence' AS EvidenceBoundary;
