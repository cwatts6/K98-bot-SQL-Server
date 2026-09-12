-- S8A synthetic validation; AUTHORED, NOT EXECUTED by file approval.
-- No connection, USE, server default, predecessor runner, real input or provider call.
-- Separately authorize an exact NEW database for EACH case. Preserve it afterwards.
-- Prerequisites: empty S2A/S2B schema and authoritative KVK.KVK_Scan definition.
-- Caller sets KVK_S8A_DISPOSABLE_AUTHORIZED=1, KVK_S8A_AUTHORIZED_SERVER,
-- KVK_S8A_AUTHORIZED_DATABASE and KVK_S8A_CASE in SESSION_CONTEXT, and provides:
-- #S8AMigrationInput (SqlText nvarchar(max), ExpectedUtf16Hash binary(32),
--   BackupEvidence nvarchar(1024), PreviewEvidence nvarchar(1024)). One non-null row.
-- Load the exact reviewed migration as a bound Unicode value; independently record
-- its file SHA-256 plus UTF-16LE hash. Never supply downloaded/unreviewed SQL text.
-- This intentionally executes the authorized migration only in later execution scope.
-- Cases: install (preview/apply/rerun), legacy (one synthetic historical classification,
--   then exact rerun and opposing-source rejection), mixed (both histories, reject),
--   unclassified (legacy history with empty allowlist, reject), partial (one incomplete
--   table, reject), constraints (S8A already installed empty; rollback-only fixture).
-- Installer cases commit only their explicit setup/migration in a new empty DB; preserve
-- the DB and rows as evidence. Constraint cases rollback every inserted fixture row.
-- Sequential uniqueness checks are NOT two-session onboarding/CAS or race evidence.
-- SQL cannot enforce authorized APIs/immutability/pair eligibility by these FKs alone.
-- S8B must prove B0 membership zeros, exact 11-10/12-10/13-10/authorized14-10 behavior,
-- counterpart confirmations, atomic complete-selection/intent and lost-ack recovery.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51900, 'S8A fixture refuses ambient transaction.', 1;
IF COALESCE(TRY_CONVERT(int,SESSION_CONTEXT(N'KVK_S8A_DISPOSABLE_AUTHORIZED')),0)<>1
 OR SESSION_CONTEXT(N'KVK_S8A_AUTHORIZED_SERVER') IS NULL OR SESSION_CONTEXT(N'KVK_S8A_AUTHORIZED_DATABASE') IS NULL
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'KVK_S8A_AUTHORIZED_SERVER')) COLLATE Latin1_General_100_BIN2<>CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
 OR CONVERT(nvarchar(128),SESSION_CONTEXT(N'KVK_S8A_AUTHORIZED_DATABASE')) COLLATE Latin1_General_100_BIN2<>DB_NAME() COLLATE Latin1_General_100_BIN2
 OR DB_ID()<=4 OR DB_NAME() NOT LIKE N'K98[_]S8A[_]Disposable[_]%'
    THROW 51900, 'Exact new S8A disposable target authorization required.', 1;
DECLARE @Case varchar(32)=CONVERT(varchar(32),SESSION_CONTEXT(N'KVK_S8A_CASE'));
IF @Case IS NULL OR @Case COLLATE Latin1_General_100_BIN2 NOT IN ('install','legacy','mixed','unclassified','partial','constraints') OR DATALENGTH(@Case)<>LEN(@Case)
    THROW 51900, 'Select an explicitly approved fixture case.', 1;
IF OBJECT_ID(N'tempdb..#S8AMigrationInput') IS NULL THROW 51900, 'Reviewed migration input/backup receipt missing.', 1;
IF (SELECT COUNT_BIG(*) FROM #S8AMigrationInput)<>1 OR EXISTS (SELECT 1 FROM #S8AMigrationInput WHERE SqlText IS NULL OR ExpectedUtf16Hash IS NULL
 OR HASHBYTES('SHA2_256',CONVERT(varbinary(max),SqlText))<>ExpectedUtf16Hash OR BackupEvidence IS NULL OR LEN(BackupEvidence)=0 OR PreviewEvidence IS NULL OR LEN(PreviewEvidence)=0)
    THROW 51900, 'Migration text/hash/evidence receipt invalid.', 1;
DECLARE @Migration nvarchar(max)=(SELECT SqlText FROM #S8AMigrationInput);
DECLARE @season int=2147483500, @utc datetime2(0)='2000-01-01T00:00:00', @choice uniqueidentifier=NEWID();
DECLARE @WasXactAbort bit=CASE WHEN (16384 & @@OPTIONS)=16384 THEN 1 ELSE 0 END;
-- Require all predecessor facts/state and legacy scan history empty; no retained S6 target.
IF EXISTS (SELECT 1 FROM KVK.SourceArtifact) THROW 51900, 'S8A fixture requires empty KVK.SourceArtifact.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceImportAttempt) THROW 51900, 'S8A fixture requires empty KVK.SourceImportAttempt.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservation) THROW 51900, 'S8A fixture requires empty KVK.SourceObservation.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservationRevision) THROW 51900, 'S8A fixture requires empty KVK.SourceObservationRevision.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerSnapshot) THROW 51900, 'S8A fixture requires empty KVK.SourcePlayerSnapshot.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceLogicalScan) THROW 51900, 'S8A fixture requires empty KVK.SourceLogicalScan.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRoster) THROW 51900, 'S8A fixture requires empty KVK.SourceRoster.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRosterMember) THROW 51900, 'S8A fixture requires empty KVK.SourceRosterMember.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateReport) THROW 51900, 'S8A fixture requires empty KVK.SourceAggregateReport.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateRevision) THROW 51900, 'S8A fixture requires empty KVK.SourceAggregateRevision.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceKingdomReportRow) THROW 51900, 'S8A fixture requires empty KVK.SourceKingdomReportRow.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampReportRow) THROW 51900, 'S8A fixture requires empty KVK.SourceCampReportRow.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigVersion) THROW 51900, 'S8A fixture requires empty KVK.SourceConfigVersion.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePeriod) THROW 51900, 'S8A fixture requires empty KVK.SourcePeriod.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWindowConfig) THROW 51900, 'S8A fixture requires empty KVK.SourceWindowConfig.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampConfig) THROW 51900, 'S8A fixture requires empty KVK.SourceCampConfig.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWeightConfig) THROW 51900, 'S8A fixture requires empty KVK.SourceWeightConfig.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceScanBinding) THROW 51900, 'S8A fixture requires empty KVK.SourceScanBinding.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigRequest) THROW 51900, 'S8A fixture requires empty KVK.SourceConfigRequest.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePublication) THROW 51900, 'S8A fixture requires empty KVK.SourcePublication.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult) THROW 51900, 'S8A fixture requires empty KVK.SourcePlayerResult.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceSelection) THROW 51900, 'S8A fixture requires empty KVK.SourceSelection.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRouting) THROW 51900, 'S8A fixture requires empty KVK.SourceRouting.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAction) THROW 51900, 'S8A fixture requires empty KVK.SourceAction.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceDelivery) THROW 51900, 'S8A fixture requires empty KVK.SourceDelivery.', 1;
IF EXISTS (SELECT 1 FROM KVK.KVK_Scan) THROW 51900, 'S8A fixture requires empty KVK.KVK_Scan.', 1;
CREATE TABLE #S8AApproval (ServerName nvarchar(128),DatabaseName sysname,BackupEvidence nvarchar(1024),PreviewEvidence nvarchar(1024),ExpectedNewChoices bigint,Mode varchar(8));
CREATE TABLE #S8AClassification (KVK_NO int,SourceKey varchar(32) COLLATE Latin1_General_100_BIN2,ChoiceID uniqueidentifier,ChosenBy nvarchar(128),ChosenUTC datetime2(0),Reason nvarchar(1024),ProvenanceJson nvarchar(max),SeasonState varchar(32),ExpectedLegacyRows bigint,ExpectedSourceRows bigint);
INSERT INTO #S8AApproval SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME(),BackupEvidence,PreviewEvidence,0,'apply' FROM #S8AMigrationInput;
IF @Case<>'constraints'
BEGIN
    IF OBJECT_ID(N'KVK.SeasonSource') IS NOT NULL THROW 51900, 'Installer case requires absent S8A objects.', 1;
    IF OBJECT_ID(N'KVK.SourceUpdate') IS NOT NULL THROW 51900, 'Installer case requires absent S8A objects.', 1;
    IF OBJECT_ID(N'KVK.SourceCompleteSelection') IS NOT NULL THROW 51900, 'Installer case requires absent S8A objects.', 1;
    IF OBJECT_ID(N'KVK.SourceExportIntent') IS NOT NULL THROW 51900, 'Installer case requires absent S8A objects.', 1;
    IF OBJECT_ID(N'KVK.SourceExportIntentPublication') IS NOT NULL THROW 51900, 'Installer case requires absent S8A objects.', 1;
    IF @Case IN ('legacy','mixed','unclassified')
    BEGIN
        INSERT INTO KVK.KVK_Scan (KVK_NO,ScanID,ScanTimestampUTC,SourceFileName,FileHash,Row_Count,ImportedAtUTC)
        VALUES (@season,1,@utc,N'S8A synthetic history',HASHBYTES('SHA2_256',N'S8A synthetic history'),1,@utc);
    END;
    IF @Case='mixed' INSERT INTO KVK.SourceRouting (SourceKey,KVK_NO,RoutingVersion) VALUES ('snapshot_report_v1',@season,1);
    IF @Case='partial' EXEC sys.sp_executesql N'CREATE TABLE KVK.SeasonSource (KVK_NO int NOT NULL);';
    IF @Case='legacy'
    BEGIN
        INSERT INTO #S8AClassification VALUES (@season,'legacy_full_data',@choice,N'synthetic',@utc,N'S8A fixture classification',N'{"synthetic":true}','closed',1,0);
        UPDATE #S8AApproval SET ExpectedNewChoices=1;
    END;
    IF @Case IN ('mixed','unclassified','partial')
    BEGIN
        BEGIN TRY
            EXEC sys.sp_executesql @Migration;
            THROW 51901, 'Invalid migration case was accepted.', 1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>CASE WHEN @Case='partial' THEN 51810 ELSE 51801 END OR @@TRANCOUNT<>0 THROW;
        END CATCH;
        IF OBJECT_ID(N'KVK.SourceUpdate') IS NOT NULL OR OBJECT_ID(N'KVK.SourceExportIntent') IS NOT NULL
            THROW 51901, 'Rejected migration left new objects.', 1;
        IF @Case IN ('mixed','unclassified') AND (SELECT COUNT_BIG(*) FROM KVK.KVK_Scan WHERE KVK_NO=@season)<>1
            THROW 51901, 'Rejected migration changed historical rows.', 1;
        IF @Case='mixed' AND NOT EXISTS (SELECT 1 FROM KVK.SourceRouting WHERE KVK_NO=@season AND Enabled=0)
            THROW 51901, 'Rejected migration changed routing.', 1;
        SELECT @Case AS PassedCase,'retained_rejection_fixture' AS Disposition;
    END
    ELSE
    BEGIN
        UPDATE #S8AApproval SET Mode='preview';
        EXEC sys.sp_executesql @Migration;
        IF OBJECT_ID(N'KVK.SeasonSource') IS NOT NULL THROW 51901, 'Preview did not rollback schema.', 1;
        UPDATE #S8AApproval SET Mode='apply';
        EXEC sys.sp_executesql @Migration;
        UPDATE #S8AApproval SET ExpectedNewChoices=0;
        EXEC sys.sp_executesql @Migration;
        IF @Case='legacy'
        BEGIN
            EXEC sys.sp_executesql N'IF (SELECT COUNT_BIG(*) FROM KVK.SeasonSource)<>1 THROW 51901, ''Rerun duplicated choices.'', 1;';
            UPDATE #S8AClassification SET SourceKey='snapshot_report_v1';
            BEGIN TRY
                EXEC sys.sp_executesql @Migration;
                THROW 51901, 'Opposing source was accepted.', 1;
            END TRY
            BEGIN CATCH
                IF ERROR_NUMBER()<>51801 OR @@TRANCOUNT<>0 THROW;
            END CATCH;
            EXEC sys.sp_executesql N'IF NOT EXISTS (SELECT 1 FROM KVK.SeasonSource WHERE SourceKey=''legacy_full_data'') THROW 51901, ''Original source changed.'', 1;';
        END;
        SELECT @Case AS PassedCase,'preview_rolled_back_apply_and_rerun_retained' AS Disposition;
    END;
    IF @WasXactAbort=1 SET XACT_ABORT ON ELSE SET XACT_ABORT OFF;
    RETURN;
END;
IF OBJECT_ID(N'KVK.SeasonSource',N'U') IS NULL THROW 51900, 'Install S8A before constraints case.', 1;
IF EXISTS (SELECT 1 FROM KVK.SeasonSource) THROW 51900, 'Constraints case requires empty KVK.SeasonSource.', 1;
IF OBJECT_ID(N'KVK.SourceUpdate',N'U') IS NULL THROW 51900, 'Install S8A before constraints case.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceUpdate) THROW 51900, 'Constraints case requires empty KVK.SourceUpdate.', 1;
IF OBJECT_ID(N'KVK.SourceCompleteSelection',N'U') IS NULL THROW 51900, 'Install S8A before constraints case.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCompleteSelection) THROW 51900, 'Constraints case requires empty KVK.SourceCompleteSelection.', 1;
IF OBJECT_ID(N'KVK.SourceExportIntent',N'U') IS NULL THROW 51900, 'Install S8A before constraints case.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceExportIntent) THROW 51900, 'Constraints case requires empty KVK.SourceExportIntent.', 1;
IF OBJECT_ID(N'KVK.SourceExportIntentPublication',N'U') IS NULL THROW 51900, 'Install S8A before constraints case.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceExportIntentPublication) THROW 51900, 'Constraints case requires empty KVK.SourceExportIntentPublication.', 1;
SET XACT_ABORT OFF;
DECLARE @Passed int=0,@cfg uniqueidentifier=NEWID(),@cfg2 uniqueidentifier=NEWID(),@roster uniqueidentifier=NEWID(),@period uniqueidentifier=NEWID(),@overall uniqueidentifier=NEWID(),@nofight uniqueidentifier=NEWID();
DECLARE @report uniqueidentifier=NEWID(),@agg uniqueidentifier=NEWID(),@pub uniqueidentifier=NEWID(),@pub2 uniqueidentifier=NEWID(),@request uniqueidentifier=NEWID();
DECLARE @update uniqueidentifier=NEWID(),@waiting uniqueidentifier=NEWID(),@zero uniqueidentifier=NEWID(),@intent uniqueidentifier=NEWID(),@intent2 uniqueidentifier=NEWID();
DECLARE @hash binary(32)=HASHBYTES('SHA2_256',N'S8A synthetic fixture');
DECLARE @scans TABLE (ScanID int PRIMARY KEY,Obs uniqueidentifier,Rev uniqueidentifier);
BEGIN TRY
BEGIN TRANSACTION;
INSERT INTO KVK.SeasonSource VALUES (@season,'snapshot_report_v1',@choice,N'synthetic',@utc,N'S8A fixture',N'{"synthetic":true}','planned',1);
INSERT INTO KVK.SeasonSource VALUES (@season+1,'legacy_full_data',NEWID(),N'synthetic',@utc,N'S8A legacy fixture',N'{"synthetic":true}','closed',1);
INSERT INTO KVK.SourceArtifact VALUES (@hash,100,LOWER(CONVERT(varchar(64),@hash,2))+N'.xlsx',@utc);
INSERT INTO @scans VALUES (10,NEWID(),NEWID()),(11,NEWID(),NEWID()),(12,NEWID(),NEWID()),(13,NEWID(),NEWID()),(14,NEWID(),NEWID());
INSERT INTO KVK.SourceObservation (ObservationID,SourceKey,KVK_NO,ScanStartUTC,TimePrecision,EventDiscriminator,SelectionVersion)
 SELECT Obs,'snapshot_report_v1',@season,DATEADD(hour,ScanID,@utc),'second',N'main',1 FROM @scans;
INSERT INTO KVK.SourceObservationRevision (RevisionID,SourceKey,KVK_NO,ObservationID,RevisionNo,SemanticHash,DigestVersion,SchemaVersion,ArtifactHash,AcceptanceState,AcceptedUTC,AcceptedBy,Reason,MetadataJson)
 SELECT Rev,'snapshot_report_v1',@season,Obs,1,@hash,'semantic_digest_v1','snapshot_report_players_v1',@hash,'accepted',@utc,N'synthetic',N'fixture',N'{}' FROM @scans;
UPDATE o SET SelectedRevisionID=s.Rev FROM KVK.SourceObservation o JOIN @scans s ON s.Obs=o.ObservationID;
INSERT INTO KVK.SourceLogicalScan SELECT 'snapshot_report_v1',@season,ScanID,Obs,@utc FROM @scans;
INSERT INTO KVK.SourceRoster SELECT @roster,'snapshot_report_v1',@season,1,Rev,@hash,@hash,1,@utc,N'synthetic',N'B0 fixture',N'{}' FROM @scans WHERE ScanID=10;
INSERT INTO KVK.SourceRosterMember VALUES (@roster,'snapshot_report_v1',@season,1,1,0);
-- B0 was admitted privately without any aggregate, complete selection or export intent.
IF EXISTS (SELECT 1 FROM KVK.SourceCompleteSelection) OR EXISTS (SELECT 1 FROM KVK.SourceExportIntent) THROW 51901, 'B0 generated public state.', 1;
INSERT INTO KVK.SourcePeriod VALUES (@period,'snapshot_report_v1',@season,'fight:synthetic','fight',@utc,NULL,@utc),(@overall,'snapshot_report_v1',@season,'overall','overall',@utc,NULL,@utc),(@nofight,'snapshot_report_v1',@season,'no_fight:synthetic','no_fight',@utc,NULL,@utc);
INSERT INTO KVK.SourceConfigVersion VALUES (@cfg,'snapshot_report_v1',@season,1,@roster,@hash,@hash,@hash,@hash,@utc,N'synthetic',N'approved',N'{}'),(@cfg2,'snapshot_report_v1',@season,2,@roster,@hash,@hash,@hash,@hash,@utc,N'synthetic',N'endpoint update',N'{}');
INSERT INTO KVK.SourceWindowConfig SELECT c.ConfigVersionID,'snapshot_report_v1',@season,p.PeriodKey,NULL,10,CASE WHEN p.PeriodKind='no_fight' THEN 10 WHEN c.ConfigVersionID=@cfg2 THEN 14 ELSE 13 END,NULL,@utc,p.PeriodKey FROM KVK.SourceConfigVersion c CROSS JOIN KVK.SourcePeriod p;
INSERT INTO KVK.SourceScanBinding SELECT c.ConfigVersionID,'snapshot_report_v1',@season,s.ScanID FROM KVK.SourceConfigVersion c CROSS JOIN @scans s;
DECLARE @start uniqueidentifier=(SELECT Rev FROM @scans WHERE ScanID=10),@end uniqueidentifier=(SELECT Rev FROM @scans WHERE ScanID=13);
INSERT INTO KVK.SourceUpdate (UpdateID,SourceKey,KVK_NO,PeriodID,PeriodKey,ChoiceID,ConfigVersionID,RosterID,StartScanID,EndScanID,StartRevisionID,EndRevisionID,CoverageStartUTC,CoverageEndUTC,AsOfUTC,UpdateKind,UpdateState,ConfirmedBy,ConfirmedUTC,ConfirmationJson,ContentHash,Version)
 VALUES (@waiting,'snapshot_report_v1',@season,@period,'fight:synthetic',@choice,@cfg,@roster,10,13,@start,@end,@utc,@utc,@utc,'fight','waiting_aggregate',N'synthetic',@utc,N'{}',@hash,1),(@zero,'snapshot_report_v1',@season,@nofight,'no_fight:synthetic',@choice,@cfg,@roster,10,10,@start,@start,@utc,@utc,@utc,'no_fight','ready',N'synthetic',@utc,N'{}',@hash,1);
IF EXISTS (SELECT 1 FROM KVK.SourceCompleteSelection) OR EXISTS (SELECT 1 FROM KVK.SourceExportIntent) THROW 51901, 'Waiting player-only update generated public state.', 1;
INSERT INTO KVK.SourceAggregateReport VALUES (@report,'snapshot_report_v1',@season,'fight:synthetic','fight',NULL,1);
INSERT INTO KVK.SourceAggregateRevision (RevisionID,SourceKey,KVK_NO,ReportID,PeriodKind,RevisionNo,ArtifactHash,SemanticHash,DigestVersion,SchemaVersion,ScanStartUTC,TimePrecision,CoverageStartUTC,CoverageEndUTC,AsOfUTC,ReportState,AcceptedUTC,AcceptedBy,Reason,MappingDigest,ScopeDigest,MetadataJson)
 VALUES (@agg,'snapshot_report_v1',@season,@report,'fight',1,@hash,@hash,'semantic_digest_v1','snapshot_report_aggregate_v1',@utc,'second',@utc,@utc,@utc,'final',@utc,N'synthetic',N'fixture',@hash,@hash,N'{}');
UPDATE KVK.SourceAggregateReport SET SelectedRevisionID=@agg WHERE ReportID=@report;
INSERT INTO KVK.SourceUpdate (UpdateID,SourceKey,KVK_NO,PeriodID,PeriodKey,ChoiceID,ConfigVersionID,RosterID,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,CoverageStartUTC,CoverageEndUTC,AsOfUTC,UpdateKind,UpdateState,ConfirmedBy,ConfirmedUTC,ConfirmationJson,ContentHash,Version)
 VALUES (@update,'snapshot_report_v1',@season,@period,'fight:synthetic',@choice,@cfg,@roster,10,13,@start,@end,@report,@agg,@utc,@utc,@utc,'fight','ready',N'synthetic',@utc,N'{}',@hash,1);
INSERT INTO KVK.SourcePublication (PublicationID,SourceKey,KVK_NO,PeriodID,PeriodKey,Generation,ConfigVersionID,RosterID,CalculationVersion,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,PlayerState,AggregateState,PeriodState,BuildState,EligibleCount,ResultCount,KingdomCount,CampCount,ManifestHash,CreatedUTC,CompletedUTC)
 VALUES (@pub,'snapshot_report_v1',@season,@period,'fight:synthetic',1,@cfg,@roster,'synthetic_v1',10,13,@start,@end,@report,@agg,'final','final','final','complete',1,1,1,1,@hash,@utc,@utc),(@pub2,'snapshot_report_v1',@season,@nofight,'no_fight:synthetic',1,@cfg,@roster,'synthetic_v1',10,10,@start,@start,NULL,NULL,'not_applicable','not_applicable','final','complete',1,1,0,0,@hash,@utc,@utc);
-- These catalog-only publications do not pretend to be computed player/aggregate facts.
-- Candidate manifest verification belongs to S8B, beyond this relational fixture.
-- wrong choice
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET ChoiceID=NEWID() WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: wrong choice', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceUpdate_Choice',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong KVK
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET KVK_NO=@season+1 WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: wrong KVK', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceUpdate_Choice',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_Period',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_Kind',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_Window',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_ConfigRoster',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_StartRevision',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_EndRevision',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_Aggregate',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_AggregateKind',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong period kind
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET PeriodID=@overall,PeriodKey='overall' WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: wrong period kind', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceUpdate_Kind',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- missing endpoint while sealed
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET EndScanID=NULL,EndRevisionID=NULL WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: missing endpoint while sealed', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_State',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- aggregate half null
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET AggregateReportID=NULL WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: aggregate half null', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_Inputs',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong revision
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET EndRevisionID=NEWID() WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: wrong revision', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceUpdate_EndRevision',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- no-fight aggregate forbidden
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET AggregateReportID=@report,AggregateRevisionID=@agg WHERE UpdateID=@zero;
    THROW 51901, 'Accepted invalid case: no-fight aggregate forbidden', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_Kind',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceUpdate_AggregateKind',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- no-fight endpoints unequal
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET EndScanID=13,EndRevisionID=@end WHERE UpdateID=@zero;
    THROW 51901, 'Accepted invalid case: no-fight endpoints unequal', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_Kind',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- invalid coverage
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET CoverageEndUTC=DATEADD(day,-1,@utc) WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: invalid coverage', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_Time',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- unbound counterpart
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceUpdate SET BaseUpdateID=@waiting,CounterpartRevisionID=NEWID() WHERE UpdateID=@update;
    THROW 51901, 'Accepted invalid case: unbound counterpart', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceUpdate_Confirmation',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
INSERT INTO KVK.SourceCompleteSelection VALUES ('snapshot_report_v1',@season,@period,@update,@pub,1,@utc),('snapshot_report_v1',@season,@nofight,@zero,@pub2,1,@utc);
INSERT INTO KVK.SourceExportIntent VALUES (@intent,'snapshot_report_v1',@season,@choice,1,@hash,'synthetic_v1','waiting_destination',@utc,NULL),(@intent2,'snapshot_report_v1',@season,@choice,2,HASHBYTES('SHA2_256',N'synthetic vector2'),'synthetic_v1','pending',@utc,NULL);
INSERT INTO KVK.SourceExportIntentPublication VALUES (@intent,@period,'snapshot_report_v1',@season,@update,@pub,1,@cfg),(@intent,@nofight,'snapshot_report_v1',@season,@zero,@pub2,1,@cfg),(@intent2,@period,'snapshot_report_v1',@season,@update,@pub,1,@cfg),(@intent2,@nofight,'snapshot_report_v1',@season,@zero,@pub2,1,@cfg);
IF (SELECT COUNT_BIG(*) FROM KVK.SourceExportIntentPublication WHERE IntentID=@intent2)<>2 THROW 51901, 'Unchanged-period vector membership lost.', 1;
-- second season choice
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT INTO KVK.SeasonSource VALUES (@season,'legacy_full_data',NEWID(),N'synthetic',@utc,N'conflict',N'{}','planned',1);
    THROW 51901, 'Accepted invalid case: second season choice', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'PK_SeasonSource',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- invalid source
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT INTO KVK.SeasonSource VALUES (@season+2,'unknown',NEWID(),N'synthetic',@utc,N'conflict',N'{}','planned',1);
    THROW 51901, 'Accepted invalid case: invalid source', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SeasonSource_Scope',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- JSON overflow
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SeasonSource SET ProvenanceJson=N'{"x":"'+REPLICATE(CONVERT(nvarchar(max),N'x'),32768)+N'"}' WHERE KVK_NO=@season;
    THROW 51901, 'Accepted invalid case: JSON overflow', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SeasonSource_Provenance',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong selection scope
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceCompleteSelection SET UpdateID=@zero WHERE PeriodID=@period;
    THROW 51901, 'Accepted invalid case: wrong selection scope', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceCompleteSelection_Update',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong publication scope
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceCompleteSelection SET PublicationID=@pub2 WHERE PeriodID=@period;
    THROW 51901, 'Accepted invalid case: wrong publication scope', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceCompleteSelection_Publication',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- zero public version
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceCompleteSelection SET PublicSelectionVersion=0 WHERE PeriodID=@period;
    THROW 51901, 'Accepted invalid case: zero public version', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceCompleteSelection_Version',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- duplicate vector hash
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT INTO KVK.SourceExportIntent VALUES (NEWID(),'snapshot_report_v1',@season,@choice,3,@hash,'synthetic_v1','pending',@utc,NULL);
    THROW 51901, 'Accepted invalid case: duplicate vector hash', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'UQ_SourceExportIntent_Vector',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- duplicate commit sequence
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT INTO KVK.SourceExportIntent VALUES (NEWID(),'snapshot_report_v1',@season,@choice,1,HASHBYTES('SHA2_256',N'other'),'synthetic_v1','pending',@utc,NULL);
    THROW 51901, 'Accepted invalid case: duplicate commit sequence', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'UQ_SourceExportIntent_Sequence',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- coalesced without successor
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceExportIntent SET IntentState='coalesced' WHERE IntentID=@intent;
    THROW 51901, 'Accepted invalid case: coalesced without successor', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceExportIntent_State',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- self successor
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceExportIntent SET IntentState='coalesced',SupersededByIntentID=@intent WHERE IntentID=@intent;
    THROW 51901, 'Accepted invalid case: self successor', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'CK_SourceExportIntent_State',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- duplicate intent membership
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT INTO KVK.SourceExportIntentPublication VALUES (@intent,@period,'snapshot_report_v1',@season,@update,@pub,1,@cfg);
    THROW 51901, 'Accepted invalid case: duplicate intent membership', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'PK_SourceExportIntentPublication',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong vector config
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceExportIntentPublication SET ConfigVersionID=@cfg2 WHERE IntentID=@intent AND PeriodID=@period;
    THROW 51901, 'Accepted invalid case: wrong vector config', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceExportIntentPublication_Update',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceExportIntentPublication_Publication',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- wrong vector season
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourceExportIntentPublication SET KVK_NO=@season+1 WHERE IntentID=@intent AND PeriodID=@period;
    THROW 51901, 'Accepted invalid case: wrong vector season', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE()<>1 THROW;
    IF CHARINDEX(N'FK_SourceExportIntentPublication_Update',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceExportIntentPublication_Publication',ERROR_MESSAGE())=0 AND CHARINDEX(N'FK_SourceExportIntentPublication_Intent',ERROR_MESSAGE())=0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
DECLARE @base uniqueidentifier=NEWID();
INSERT INTO KVK.SourceUpdate (UpdateID, SourceKey, KVK_NO, PeriodID, PeriodKey, ChoiceID, ConfigVersionID, RosterID, StartScanID, EndScanID, StartRevisionID, EndRevisionID, AggregateReportID, AggregateRevisionID, CoverageStartUTC, CoverageEndUTC, AsOfUTC, UpdateKind, UpdateState, BaseUpdateID, CounterpartRevisionID, ConfirmedBy, ConfirmedUTC, ConfirmationJson, RequestID, ContentHash, Version) SELECT @base,SourceKey, KVK_NO, PeriodID, PeriodKey, ChoiceID, ConfigVersionID, RosterID, StartScanID, EndScanID, StartRevisionID, EndRevisionID, AggregateReportID, AggregateRevisionID, CoverageStartUTC, CoverageEndUTC, AsOfUTC, UpdateKind, UpdateState, BaseUpdateID, CounterpartRevisionID, ConfirmedBy, ConfirmedUTC, ConfirmationJson, RequestID, ContentHash, Version FROM KVK.SourceUpdate WHERE UpdateID=@update;
-- Explicit retained counterpart references an accepted revision without creating a scan.
UPDATE KVK.SourceUpdate SET BaseUpdateID=@base,CounterpartRevisionID=@agg,ConfirmationJson=N'{"synthetic":true,"reason":"retained counterpart valid"}' WHERE UpdateID=@update;
IF (SELECT COUNT_BIG(*) FROM KVK.SourceLogicalScan)<>5 THROW 51901, 'Counterpart reuse allocated a scan.', 1;
UPDATE KVK.SourceExportIntent SET IntentState='coalesced',SupersededByIntentID=@intent2 WHERE IntentID=@intent;
IF (SELECT COUNT_BIG(*) FROM KVK.SourceExportIntent)<>2 THROW 51901, 'Coalescing erased history.', 1;
ROLLBACK TRANSACTION;
IF EXISTS (SELECT 1 FROM KVK.SeasonSource) THROW 51901, 'Synthetic rows survived rollback: SeasonSource', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceUpdate) THROW 51901, 'Synthetic rows survived rollback: SourceUpdate', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCompleteSelection) THROW 51901, 'Synthetic rows survived rollback: SourceCompleteSelection', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceExportIntent) THROW 51901, 'Synthetic rows survived rollback: SourceExportIntent', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceExportIntentPublication) THROW 51901, 'Synthetic rows survived rollback: SourceExportIntentPublication', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceArtifact) THROW 51901, 'Synthetic rows survived rollback: SourceArtifact', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceImportAttempt) THROW 51901, 'Synthetic rows survived rollback: SourceImportAttempt', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservation) THROW 51901, 'Synthetic rows survived rollback: SourceObservation', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservationRevision) THROW 51901, 'Synthetic rows survived rollback: SourceObservationRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerSnapshot) THROW 51901, 'Synthetic rows survived rollback: SourcePlayerSnapshot', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceLogicalScan) THROW 51901, 'Synthetic rows survived rollback: SourceLogicalScan', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRoster) THROW 51901, 'Synthetic rows survived rollback: SourceRoster', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRosterMember) THROW 51901, 'Synthetic rows survived rollback: SourceRosterMember', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateReport) THROW 51901, 'Synthetic rows survived rollback: SourceAggregateReport', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateRevision) THROW 51901, 'Synthetic rows survived rollback: SourceAggregateRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceKingdomReportRow) THROW 51901, 'Synthetic rows survived rollback: SourceKingdomReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampReportRow) THROW 51901, 'Synthetic rows survived rollback: SourceCampReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigVersion) THROW 51901, 'Synthetic rows survived rollback: SourceConfigVersion', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePeriod) THROW 51901, 'Synthetic rows survived rollback: SourcePeriod', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWindowConfig) THROW 51901, 'Synthetic rows survived rollback: SourceWindowConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampConfig) THROW 51901, 'Synthetic rows survived rollback: SourceCampConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWeightConfig) THROW 51901, 'Synthetic rows survived rollback: SourceWeightConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceScanBinding) THROW 51901, 'Synthetic rows survived rollback: SourceScanBinding', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigRequest) THROW 51901, 'Synthetic rows survived rollback: SourceConfigRequest', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePublication) THROW 51901, 'Synthetic rows survived rollback: SourcePublication', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult) THROW 51901, 'Synthetic rows survived rollback: SourcePlayerResult', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceSelection) THROW 51901, 'Synthetic rows survived rollback: SourceSelection', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRouting) THROW 51901, 'Synthetic rows survived rollback: SourceRouting', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAction) THROW 51901, 'Synthetic rows survived rollback: SourceAction', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceDelivery) THROW 51901, 'Synthetic rows survived rollback: SourceDelivery', 1;
IF EXISTS (SELECT 1 FROM KVK.KVK_Scan) THROW 51901, 'Synthetic rows survived rollback: KVK_Scan', 1;
IF @WasXactAbort=1 SET XACT_ABORT ON ELSE SET XACT_ABORT OFF;
SELECT @Passed AS NegativeConstraintsPassed,'all_synthetic_rows_rolled_back' AS Disposition;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @WasXactAbort=1 SET XACT_ABORT ON ELSE SET XACT_ABORT OFF;
    THROW;
END CATCH;

/* Two-session schedules; proposed, NOT executed and not replaced by the cases above.
1. Concurrent installer: two dedicated sessions, identical explicit migration input and
   expected zero rows against empty install DB. A holds KVK.S8A.SchemaClassification;
   B must wait or error 51800 after 10s, never create a partial schema. Commit A, rerun B;
   catalog verifies five tables without mutation. Capture lock observations and errors.
2. Same/different source: on a fresh S8A schema with a new synthetic KVK, A begins and
   SELECTs SeasonSource WITH (UPDLOCK,HOLDLOCK) WHERE KVK_NO=<synthetic>; inserts choice.
   B does the same lookup and must wait. A commits. B compares the existing choice:
   same source returns original ChoiceID (no insert); opposing source returns conflict.
   If A rolls back, B may create its authorized choice. No reset/delete for another case;
   use another synthetic KVK. SQL unique PK is the last guard; S8B owns API semantics.
3. Complete-pair/vector: S8B integration must use SeasonSource, SourceRouting, sorted
   component/complete period rows, config/request/update, intent/vector locks. A and B
   complete different periods; B waits on the season row, then copies A's committed
   unchanged-period membership. Kill before commit rolls back pointer and vector; kill
   after commit/lost acknowledgment reuses the exact intent. Not runnable until S8B.
No process kill, new session, SQL connection or database cleanup is authorized here.
*/
