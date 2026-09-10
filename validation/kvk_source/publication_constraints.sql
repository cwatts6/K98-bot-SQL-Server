-- S2B synthetic rollback-only checks. No production default, connection, USE or SQLCMD target.
-- Caller must set the three authorization session-context values before executing this batch.
-- This proves relational storage foundations, not S3B/S4B CAS, semantic calculation,
-- immutable-write enforcement, commit-time completeness or external delivery/restart behavior.
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT <> 0 THROW 51300, 'Fixture refuses an ambient transaction.', 1;
IF TRY_CONVERT(int, SESSION_CONTEXT(N'KVK_S2B_DISPOSABLE_AUTHORIZED')) IS NULL
 OR TRY_CONVERT(int, SESSION_CONTEXT(N'KVK_S2B_DISPOSABLE_AUTHORIZED')) <> 1
 OR CONVERT(nvarchar(128), SESSION_CONTEXT(N'KVK_S2B_AUTHORIZED_SERVER')) IS NULL
 OR CONVERT(nvarchar(128), SESSION_CONTEXT(N'KVK_S2B_AUTHORIZED_DATABASE')) IS NULL
 OR CONVERT(nvarchar(128), SESSION_CONTEXT(N'KVK_S2B_AUTHORIZED_SERVER')) COLLATE Latin1_General_100_BIN2 <> CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
 OR CONVERT(nvarchar(128), SESSION_CONTEXT(N'KVK_S2B_AUTHORIZED_DATABASE')) COLLATE Latin1_General_100_BIN2 <> DB_NAME() COLLATE Latin1_General_100_BIN2
 OR DB_ID() <= 4 OR DB_NAME() NOT LIKE N'K98[_]S2B[_]Disposable[_]%'
    THROW 51300, 'Explicit authorization for this exact disposable target is required.', 1;
DECLARE @WasXactAbort bit = CASE WHEN (16384 & @@OPTIONS) = 16384 THEN 1 ELSE 0 END;
DECLARE @WasRoundAbort bit = CASE WHEN (8192 & @@OPTIONS) = 8192 THEN 1 ELSE 0 END;
SET XACT_ABORT OFF;
SET NUMERIC_ROUNDABORT OFF;
DECLARE @season int = 2147483600, @utc datetime2(0) = '2000-01-01T00:00:00';
DECLARE @cfg uniqueidentifier=NEWID(), @cfg2 uniqueidentifier=NEWID(), @cfg3 uniqueidentifier=NEWID();
DECLARE @roster uniqueidentifier=NEWID(), @period uniqueidentifier=NEWID(), @overall uniqueidentifier=NEWID();
DECLARE @report uniqueidentifier=NEWID(), @agg uniqueidentifier=NEWID(), @request uniqueidentifier=NEWID();
DECLARE @pub uniqueidentifier=NEWID(), @pub2 uniqueidentifier=NEWID(), @pub3 uniqueidentifier=NEWID(), @pub4 uniqueidentifier=NEWID();
DECLARE @hash binary(32)=HASHBYTES('SHA2_256', CONVERT(varbinary(16), NEWID()));
DECLARE @scans TABLE (ScanID int PRIMARY KEY, Obs uniqueidentifier, Rev uniqueidentifier);
DECLARE @Passed int=0;
BEGIN TRY
BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM KVK.SourceArtifact) THROW 51300, 'Fixture requires empty foundation: SourceArtifact', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceImportAttempt) THROW 51300, 'Fixture requires empty foundation: SourceImportAttempt', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservation) THROW 51300, 'Fixture requires empty foundation: SourceObservation', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservationRevision) THROW 51300, 'Fixture requires empty foundation: SourceObservationRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerSnapshot) THROW 51300, 'Fixture requires empty foundation: SourcePlayerSnapshot', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceLogicalScan) THROW 51300, 'Fixture requires empty foundation: SourceLogicalScan', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRoster) THROW 51300, 'Fixture requires empty foundation: SourceRoster', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRosterMember) THROW 51300, 'Fixture requires empty foundation: SourceRosterMember', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateReport) THROW 51300, 'Fixture requires empty foundation: SourceAggregateReport', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateRevision) THROW 51300, 'Fixture requires empty foundation: SourceAggregateRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceKingdomReportRow) THROW 51300, 'Fixture requires empty foundation: SourceKingdomReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampReportRow) THROW 51300, 'Fixture requires empty foundation: SourceCampReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigVersion) THROW 51300, 'Fixture requires empty foundation: SourceConfigVersion', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePeriod) THROW 51300, 'Fixture requires empty foundation: SourcePeriod', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWindowConfig) THROW 51300, 'Fixture requires empty foundation: SourceWindowConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampConfig) THROW 51300, 'Fixture requires empty foundation: SourceCampConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWeightConfig) THROW 51300, 'Fixture requires empty foundation: SourceWeightConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceScanBinding) THROW 51300, 'Fixture requires empty foundation: SourceScanBinding', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigRequest) THROW 51300, 'Fixture requires empty foundation: SourceConfigRequest', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePublication) THROW 51300, 'Fixture requires empty foundation: SourcePublication', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult) THROW 51300, 'Fixture requires empty foundation: SourcePlayerResult', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceSelection) THROW 51300, 'Fixture requires empty foundation: SourceSelection', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRouting) THROW 51300, 'Fixture requires empty foundation: SourceRouting', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAction) THROW 51300, 'Fixture requires empty foundation: SourceAction', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceDelivery) THROW 51300, 'Fixture requires empty foundation: SourceDelivery', 1;
INSERT KVK.SourceArtifact VALUES (@hash,100,LOWER(CONVERT(varchar(64),@hash,2))+N'.xlsx',@utc);
INSERT @scans VALUES (10,NEWID(),NEWID()),(11,NEWID(),NEWID()),(12,NEWID(),NEWID()),(13,NEWID(),NEWID());
INSERT KVK.SourceObservation (ObservationID,SourceKey,KVK_NO,ScanStartUTC,TimePrecision,EventDiscriminator,SelectionVersion)
 SELECT Obs,'snapshot_report_v1',@season,DATEADD(hour,ScanID,@utc),'second',N'main',1 FROM @scans;
INSERT KVK.SourceObservationRevision (RevisionID,SourceKey,KVK_NO,ObservationID,RevisionNo,SemanticHash,DigestVersion,SchemaVersion,ArtifactHash,AcceptanceState,AcceptedUTC,AcceptedBy,Reason,MetadataJson)
 SELECT Rev,'snapshot_report_v1',@season,Obs,1,@hash,'semantic_digest_v1','snapshot_report_players_v1',@hash,'accepted',@utc,N'synthetic',N'fixture',N'{}' FROM @scans;
UPDATE o SET SelectedRevisionID=s.Rev FROM KVK.SourceObservation o JOIN @scans s ON s.Obs=o.ObservationID;
INSERT KVK.SourceLogicalScan SELECT 'snapshot_report_v1',@season,ScanID,Obs,@utc FROM @scans;
INSERT KVK.SourceRoster SELECT @roster,'snapshot_report_v1',@season,1,Rev,@hash,@hash,1,@utc,N'synthetic',N'B0 fixture',N'{}' FROM @scans WHERE ScanID=10;
INSERT KVK.SourceRosterMember VALUES (@roster,'snapshot_report_v1',@season,1,1,0);
INSERT KVK.SourcePeriod VALUES (@period,'snapshot_report_v1',@season,'fight:synthetic','fight',@utc,NULL,@utc),(@overall,'snapshot_report_v1',@season,'overall','overall',@utc,NULL,@utc);
INSERT KVK.SourceAggregateReport VALUES (@report,'snapshot_report_v1',@season,'fight:synthetic','fight',NULL,1);
INSERT KVK.SourceAggregateRevision (RevisionID,SourceKey,KVK_NO,ReportID,PeriodKind,RevisionNo,ArtifactHash,SemanticHash,DigestVersion,SchemaVersion,ScanStartUTC,TimePrecision,CoverageStartUTC,CoverageEndUTC,AsOfUTC,ReportState,AcceptedUTC,AcceptedBy,Reason,MappingDigest,ScopeDigest,MetadataJson)
 VALUES (@agg,'snapshot_report_v1',@season,@report,'fight',1,@hash,@hash,'semantic_digest_v1','snapshot_report_aggregate_v1',@utc,'second',@utc,@utc,@utc,'final',@utc,N'synthetic',N'fixture',@hash,@hash,N'{}');
UPDATE KVK.SourceAggregateReport SET SelectedRevisionID=@agg WHERE ReportID=@report;
INSERT KVK.SourceConfigVersion VALUES
 (@cfg,'snapshot_report_v1',@season,1,@roster,@hash,@hash,@hash,@hash,@utc,N'synthetic',N'approved',N'{}'),
 (@cfg2,'snapshot_report_v1',@season,2,@roster,@hash,@hash,@hash,@hash,@utc,N'synthetic',N'endpoint change only',N'{}'),
 (@cfg3,'snapshot_report_v1',@season,3,@roster,@hash,@hash,@hash,@hash,@utc,N'synthetic',N'return endpoint',N'{}');
INSERT KVK.SourceWindowConfig SELECT ConfigVersionID,'snapshot_report_v1',@season,N'Fight',1,10,CASE WHEN ConfigVersionID=@cfg2 THEN 14 ELSE 13 END,NULL,@utc,'fight:synthetic' FROM KVK.SourceConfigVersion;
INSERT KVK.SourceCampConfig SELECT ConfigVersionID,'snapshot_report_v1',@season,1,1,N'Synthetic camp',N'synthetic camp' FROM KVK.SourceConfigVersion;
INSERT KVK.SourceWeightConfig SELECT ConfigVersionID,'snapshot_report_v1',@season,10,20,40,'10','20','40',@utc FROM KVK.SourceConfigVersion;
INSERT KVK.SourceScanBinding SELECT c.ConfigVersionID,'snapshot_report_v1',@season,s.ScanID FROM KVK.SourceConfigVersion c CROSS JOIN @scans s;
INSERT KVK.SourcePublication (PublicationID,SourceKey,KVK_NO,PeriodID,PeriodKey,Generation,ConfigVersionID,RosterID,CalculationVersion,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,PlayerState,AggregateState,PeriodState,BuildState,EligibleCount,ResultCount,KingdomCount,CampCount,ManifestHash,CreatedUTC,CompletedUTC) SELECT @pub,'snapshot_report_v1',@season,@period,'fight:synthetic',1,@cfg,@roster,'synthetic_v1',10,11,s.Rev,e.Rev,@report,@agg,'live','final','live','complete',1,1,1,1,@hash,@utc,@utc FROM @scans s CROSS JOIN @scans e WHERE s.ScanID=10 AND e.ScanID=11;
INSERT KVK.SourcePublication (PublicationID,SourceKey,KVK_NO,PeriodID,PeriodKey,Generation,ConfigVersionID,RosterID,CalculationVersion,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,PlayerState,AggregateState,PeriodState,BuildState,EligibleCount,ResultCount,KingdomCount,CampCount,ManifestHash,CreatedUTC,CompletedUTC) SELECT @pub2,'snapshot_report_v1',@season,@period,'fight:synthetic',2,@cfg,@roster,'synthetic_v1',10,12,s.Rev,e.Rev,@report,@agg,'live','final','live','complete',1,1,1,1,@hash,@utc,@utc FROM @scans s CROSS JOIN @scans e WHERE s.ScanID=10 AND e.ScanID=12;
INSERT KVK.SourcePublication (PublicationID,SourceKey,KVK_NO,PeriodID,PeriodKey,Generation,ConfigVersionID,RosterID,CalculationVersion,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,PlayerState,AggregateState,PeriodState,BuildState,EligibleCount,ResultCount,KingdomCount,CampCount,ManifestHash,CreatedUTC,CompletedUTC) SELECT @pub3,'snapshot_report_v1',@season,@period,'fight:synthetic',3,@cfg,@roster,'synthetic_v1',10,13,s.Rev,e.Rev,@report,@agg,'final','final','final','complete',1,1,1,1,@hash,@utc,@utc FROM @scans s CROSS JOIN @scans e WHERE s.ScanID=10 AND e.ScanID=13;
INSERT KVK.SourcePlayerResult (PublicationID,SourceKey,KVK_NO,ConfigVersionID,RosterID,GovernorID,b0_kingdom,CampID,name,FieldStatusJson,starting_power,power,troops_power,t1_kills,t2_kills,t3_kills,t4_kills,t5_kills,total_kill_points,dead,healed,acclaim,highest_acclaim,kp_t4_t5,dkp,healed_points,dkp_power_ratio) SELECT PublicationID,'snapshot_report_v1',@season,@cfg,@roster,1,1,1,N'Synthetic',N'{"starting_power":"available","power":"available","troops_power":"available","t1_kills":"available","t2_kills":"available","t3_kills":"available","t4_kills":"available","t5_kills":"available","total_kill_points":"available","dead":"available","healed":"available","acclaim":"available","highest_acclaim":"available","kp_t4_t5":"available","dkp":"available","healed_points":"available","dkp_power_ratio":"not_applicable"}',0,-2000000,-2000000,0,0,0,40,50,0,10,0,0,0,1400,1800,0,NULL FROM KVK.SourcePublication;
INSERT KVK.SourceSelection VALUES ('snapshot_report_v1',@season,@period,@pub3,3,@utc);
INSERT KVK.SourceRouting (SourceKey,KVK_NO,RoutingVersion) VALUES ('snapshot_report_v1',@season,1);
IF EXISTS (SELECT 1 FROM KVK.SourceRouting WHERE Enabled<>0) THROW 51300, 'Routing activated by default.', 1;
INSERT KVK.SourceConfigRequest VALUES (@request,'snapshot_report_v1',@season,@period,'fight:synthetic',@cfg,@cfg2,@hash,10,13,10,14,'authorized_import',N'synthetic',@utc,'pending',NULL,NULL,N'authorized endpoint update',N'{}');
IF NOT EXISTS (SELECT 1 FROM KVK.SourceConfigRequest r JOIN KVK.SourceSelection s ON s.PeriodID=r.PeriodID JOIN KVK.SourcePublication p ON p.PublicationID=s.PublicationID WHERE r.RequestState='pending' AND r.NewEndScanID=14 AND p.EndScanID=13 AND p.ConfigVersionID<>r.DesiredConfigVersionID)
 THROW 51300, 'Absent endpoint failed to retain distinct desired and published configuration.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceLogicalScan WHERE LogicalScanID=14) THROW 51300, 'Pending request allocated missing endpoint.', 1;
-- Explicit synthetic arrival of 14; no automatic command or later-slice worker is invoked.
INSERT @scans VALUES (14,NEWID(),NEWID());
INSERT KVK.SourceObservation (ObservationID,SourceKey,KVK_NO,ScanStartUTC,TimePrecision,EventDiscriminator,SelectionVersion)
 SELECT Obs,'snapshot_report_v1',@season,DATEADD(hour,14,@utc),'second',N'main',1 FROM @scans WHERE ScanID=14;
INSERT KVK.SourceObservationRevision (RevisionID,SourceKey,KVK_NO,ObservationID,RevisionNo,SemanticHash,DigestVersion,SchemaVersion,ArtifactHash,AcceptanceState,AcceptedUTC,AcceptedBy,Reason,MetadataJson)
 SELECT Rev,'snapshot_report_v1',@season,Obs,1,@hash,'semantic_digest_v1','snapshot_report_players_v1',@hash,'accepted',@utc,N'synthetic',N'fixture',N'{}' FROM @scans WHERE ScanID=14;
INSERT KVK.SourceLogicalScan SELECT 'snapshot_report_v1',@season,ScanID,Obs,@utc FROM @scans WHERE ScanID=14;
INSERT KVK.SourceScanBinding VALUES (@cfg2,'snapshot_report_v1',@season,14);
INSERT KVK.SourcePublication (PublicationID,SourceKey,KVK_NO,PeriodID,PeriodKey,Generation,ConfigVersionID,RosterID,CalculationVersion,StartScanID,EndScanID,StartRevisionID,EndRevisionID,AggregateReportID,AggregateRevisionID,PlayerState,AggregateState,PeriodState,BuildState,EligibleCount,ResultCount,KingdomCount,CampCount,ManifestHash,CreatedUTC,CompletedUTC) SELECT @pub4,'snapshot_report_v1',@season,@period,'fight:synthetic',4,@cfg2,@roster,'synthetic_v1',10,14,s.Rev,e.Rev,@report,@agg,'corrected_final','final','corrected_final','complete',1,1,1,1,@hash,@utc,@utc FROM @scans s CROSS JOIN @scans e WHERE s.ScanID=10 AND e.ScanID=14;
INSERT KVK.SourcePlayerResult (PublicationID,SourceKey,KVK_NO,ConfigVersionID,RosterID,GovernorID,b0_kingdom,CampID,name,FieldStatusJson,starting_power,power,troops_power,t1_kills,t2_kills,t3_kills,t4_kills,t5_kills,total_kill_points,dead,healed,acclaim,highest_acclaim,kp_t4_t5,dkp,healed_points,dkp_power_ratio) SELECT @pub4,'snapshot_report_v1',@season,@cfg2,@roster,1,1,1,N'Synthetic',N'{"starting_power":"available","power":"available","troops_power":"available","t1_kills":"available","t2_kills":"available","t3_kills":"available","t4_kills":"available","t5_kills":"available","total_kill_points":"available","dead":"available","healed":"available","acclaim":"available","highest_acclaim":"available","kp_t4_t5":"available","dkp":"available","healed_points":"available","dkp_power_ratio":"not_applicable"}',0,-2000000,-2000000,0,0,0,40,50,0,10,0,0,0,1400,1800,0,NULL;
UPDATE KVK.SourceConfigRequest SET RequestState='applied',AppliedPublicationID=@pub4,CompletedUTC=@utc WHERE RequestID=@request;
UPDATE KVK.SourceSelection SET PublicationID=@pub4,SelectionVersion=4 WHERE PeriodID=@period;
INSERT KVK.SourceAction VALUES (NEWID(),'snapshot_report_v1',@season,@period,'endpoint_update',N'synthetic',3,4,@pub3,@pub4,@request,N'normal authorized endpoint update',@utc,N'{}');
-- Returning to 13 uses the new base version, even with identical content hash.
INSERT KVK.SourceConfigRequest VALUES (NEWID(),'snapshot_report_v1',@season,@period,'fight:synthetic',@cfg2,@cfg3,@hash,10,14,10,13,'authorized_import',N'synthetic',@utc,'pending',NULL,NULL,N'return endpoint',N'{}');
IF (SELECT COUNT(*) FROM KVK.SourceConfigRequest)<>2 THROW 51300, '13-14-13 request identity was suppressed.', 1;
IF (SELECT COUNT(*) FROM KVK.SourcePublication)<>4 OR (SELECT COUNT(*) FROM KVK.SourceLogicalScan)<>5
 THROW 51300, 'History or separate player scan registry was lost.', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePublication WHERE AggregateRevisionID<>@agg)
 THROW 51300, 'Endpoint changes altered the aggregate authority.', 1;
UPDATE KVK.SourceSelection SET PublicationID=@pub3,SelectionVersion=5 WHERE PeriodID=@period;
INSERT KVK.SourceAction VALUES (NEWID(),'snapshot_report_v1',@season,@period,'rollback',N'synthetic',4,5,@pub4,@pub3,NULL,N'fixture retained prior generation',@utc,N'{}');
INSERT KVK.SourceDelivery VALUES (@pub3,'snapshot_report_v1',@season,@period,'discord',N'synthetic-destination','pending',0,NULL,0,NULL,@utc,@utc,NULL,NULL);
UPDATE KVK.SourceDelivery SET DeliveryState='claimed',AttemptCount=1,OwnerID=NEWID(),Fence=1,ClaimedUTC=@utc;
UPDATE KVK.SourceDelivery SET DeliveryState='uncertain',Receipt=N'synthetic unresolved receipt';
IF NOT EXISTS (SELECT 1 FROM KVK.SourceDelivery WHERE DeliveryState='uncertain' AND OwnerID IS NOT NULL AND Fence=1 AND Receipt IS NOT NULL)
 THROW 51300, 'Uncertain receipt lost owner/fence/evidence.', 1;
UPDATE KVK.SourceDelivery SET DeliveryState='confirmed',ConfirmedUTC=@utc,Receipt=N'synthetic-confirmed';

-- PR review: independent periods may share the same imported configuration transition.
INSERT KVK.SourceWindowConfig SELECT ConfigVersionID,'snapshot_report_v1',@season,N'Overall',NULL,10,CASE WHEN ConfigVersionID=@cfg2 THEN 14 ELSE 13 END,NULL,@utc,'overall' FROM KVK.SourceConfigVersion;
INSERT KVK.SourceConfigRequest VALUES (NEWID(),'snapshot_report_v1',@season,@overall,'overall',@cfg,@cfg2,@hash,10,13,10,14,'authorized_import',N'synthetic',@utc,'pending',NULL,NULL,N'overall endpoint update',N'{}');
IF (SELECT COUNT(*) FROM KVK.SourceConfigRequest WHERE BaseConfigVersionID=@cfg AND ConfigContentHash=@hash)<>2
 THROW 51300, 'Independent period request was suppressed.', 1;
-- A second valid camp mapping must not allow a governor to leave their B0 kingdom.
INSERT KVK.SourceCampConfig SELECT ConfigVersionID,'snapshot_report_v1',@season,2,2,N'Other synthetic camp',N'other synthetic camp' FROM KVK.SourceConfigVersion;
SAVE TRANSACTION ValidReviewStates;
UPDATE KVK.SourcePublication SET PlayerState='final_unavailable',PeriodState='final',FinalUnavailableReason=N'explicit terminal player designation' WHERE PublicationID=@pub;
UPDATE KVK.SourcePublication SET PlayerState='final',AggregateState='final_unavailable',AggregateReportID=NULL,AggregateRevisionID=NULL,PeriodState='corrected_final',FinalUnavailableReason=N'explicit terminal aggregate designation' WHERE PublicationID=@pub2;
UPDATE KVK.SourcePublication SET PlayerState='final_unavailable',AggregateState='final_unavailable',AggregateReportID=NULL,AggregateRevisionID=NULL,PeriodState='final',FinalUnavailableReason=N'both streams terminal unavailable' WHERE PublicationID=@pub3;
IF (SELECT COUNT(*) FROM KVK.SourcePublication WHERE PlayerState='final_unavailable' OR AggregateState='final_unavailable')<>3
 THROW 51300, 'Explicit terminal unavailable states were not retained.', 1;
ROLLBACK TRANSACTION ValidReviewStates;

-- Each rejection must be the intended constraint class; unexpected SQL errors fail the harness.
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='final',PlayerState='live',AggregateState='live',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: final rejects live/live despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='final',PlayerState='live',AggregateState='final',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: final rejects live/final despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='final',PlayerState='final',AggregateState='live',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: final rejects final/live despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='final',PlayerState='missing_end',AggregateState='final',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: final rejects missing_end/final despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='corrected_final',PlayerState='live',AggregateState='live',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: corrected_final rejects live/live despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='corrected_final',PlayerState='live',AggregateState='final',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: corrected_final rejects live/final despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='corrected_final',PlayerState='final',AggregateState='live',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: corrected_final rejects final/live despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PeriodState='corrected_final',PlayerState='missing_end',AggregateState='final',FinalUnavailableReason=N'not terminal authority' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: corrected_final rejects missing_end/final despite reason', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PlayerState='final_unavailable',PeriodState='final',FinalUnavailableReason=NULL WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: terminal unavailable rejects reason NULL', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PlayerState='final_unavailable',PeriodState='final',FinalUnavailableReason=N'' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: terminal unavailable rejects reason N', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePublication SET PlayerState='final_unavailable',PeriodState='final',FinalUnavailableReason=N'   ' WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: terminal unavailable rejects reason N___', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Final', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    UPDATE KVK.SourcePlayerResult SET b0_kingdom=2,CampID=2 WHERE PublicationID=@pub;
    THROW 51301, 'Accepted invalid case: wrong B0 kingdom with valid camp', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourcePlayerResult_Eligible', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    INSERT KVK.SourceConfigRequest SELECT NEWID(),SourceKey,KVK_NO,PeriodID,PeriodKey,BaseConfigVersionID,DesiredConfigVersionID,ConfigContentHash,OldStartScanID,OldEndScanID,NewStartScanID,NewEndScanID,Origin,Actor,RequestedUTC,RequestState,AppliedPublicationID,CompletedUTC,Reason,ProvenanceJson FROM KVK.SourceConfigRequest WHERE PeriodID=@overall;
    THROW 51301, 'Accepted invalid case: overall duplicate request base hash', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'UQ_SourceConfigRequest_Replay', ERROR_MESSAGE()) = 0 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;

SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigVersion SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceConfigVersion rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigVersion SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceConfigVersion rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePeriod SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePeriod rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePeriod SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePeriod rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceWindowConfig rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceWindowConfig rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceCampConfig SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceCampConfig rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceCampConfig SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceCampConfig rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWeightConfig SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceWeightConfig rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWeightConfig SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceWeightConfig rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceScanBinding SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceScanBinding rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceScanBinding SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceScanBinding rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigRequest SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceConfigRequest rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigRequest SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceConfigRequest rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePublication rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePublication rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePlayerResult rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourcePlayerResult rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceSelection SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceSelection rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceSelection SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceSelection rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceRouting SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceRouting rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceRouting SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceRouting rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceAction SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceAction rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceAction SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceAction rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET KVK_NO=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceDelivery rejects cross-season identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET SourceKey=''SNAPSHOT_REPORT_V1''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: SourceDelivery rejects source casing', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigVersion SET RosterID=NEWID()', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: foreign roster', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourceConfigVersion_Roster', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: foreign roster'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigVersion SET ConfigVersion=1 WHERE ConfigVersionID=@cfg2', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: duplicate config version', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'UQ_SourceConfigVersion_Version', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: duplicate config version'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET PeriodKey=''fight:missing''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: unmapped period', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET EndScanID=9', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: reversed endpoint', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceWindowConfig_Bounds', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: reversed endpoint'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET EndScanID=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: zero endpoint', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceWindowConfig_Bounds', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: zero endpoint'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWindowConfig SET StartScanID=-1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: negative start', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceWindowConfig_Bounds', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: negative start'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceCampConfig SET CampID=9', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: camp outside range', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceCampConfig SET CampKey=N'' ''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: blank camp key', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceCampConfig_Identity', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: blank camp key'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWeightConfig SET WeightT4XSource=''''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: blank weight provenance', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceWeightConfig_Strings', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: blank weight provenance'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceWeightConfig SET WeightT4X=CONVERT(decimal(38,12),''100000000000000000000000000'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: weight overflow', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'overflow', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: weight overflow'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'INSERT KVK.SourceScanBinding VALUES (@cfg,''snapshot_report_v1'',@season,99)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: unknown logical scan', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourceScanBinding_Scan', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: unknown logical scan'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'INSERT KVK.SourceScanBinding VALUES (@cfg,''snapshot_report_v1'',@season,10)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: duplicate scan binding', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'PK_SourceScanBinding', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: duplicate scan binding'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'INSERT KVK.SourceConfigRequest SELECT NEWID(),SourceKey,KVK_NO,PeriodID,PeriodKey,BaseConfigVersionID,DesiredConfigVersionID,ConfigContentHash,OldStartScanID,OldEndScanID,NewStartScanID,NewEndScanID,Origin,Actor,RequestedUTC,RequestState,AppliedPublicationID,CompletedUTC,Reason,ProvenanceJson FROM KVK.SourceConfigRequest WHERE RequestID=@request', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: duplicate request base hash', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'UQ_SourceConfigRequest_Replay', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: duplicate request base hash'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigRequest SET AppliedPublicationID=@pub3 WHERE RequestID=@request', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: wrong applied config', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourceConfigRequest_Applied', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: wrong applied config'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigRequest SET AppliedPublicationID=NULL WHERE RequestID=@request', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: applied missing receipt', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceConfigRequest_State', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: applied missing receipt'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceConfigRequest SET RequestState=''APPLIED'' WHERE RequestID=@request', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: noncanonical request state', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceConfigRequest_State', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: noncanonical request state'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET Generation=1 WHERE PublicationID=@pub2', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: duplicate generation', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'UQ_SourcePublication_Generation', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: duplicate generation'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET ManifestHash=NULL WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: incomplete manifest', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Build', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: incomplete manifest'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET ResultCount=0 WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: incomplete count', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Build', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: incomplete count'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET EndRevisionID=NEWID() WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: unknown revision', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourcePublication_EndRevision', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: unknown revision'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET EndScanID=99 WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: unknown binding', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourcePublication_EndBinding', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: unknown binding'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET AggregateReportID=NULL WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: partial aggregate input', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePublication_Inputs', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: partial aggregate input'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePublication SET PeriodID=@overall WHERE PublicationID=@pub3', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: mixed period identity', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'INSERT KVK.SourceSelection VALUES (''snapshot_report_v1'',@season,@overall,@pub3,1,@utc)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: wrong selection period', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourceSelection_Publication', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: wrong selection period'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceSelection SET SelectionVersion=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: selection version zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceSelection_Version', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: selection version zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceRouting SET Enabled=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: implicit activation', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceRouting_Approval', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: implicit activation'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceRouting SET DisplayPeriodID=@overall', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: unselected display period', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourceRouting_Period', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: unselected display period'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceAction SET NewSelectionVersion=ExpectedSelectionVersion', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: rollback version does not advance', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceAction_Version', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: rollback version does not advance'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceAction SET RequestID=NULL WHERE ActionType=''endpoint_update''', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: missing endpoint authority', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceAction_Type', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: missing endpoint authority'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET Receipt=NULL', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: confirmed without receipt', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceDelivery_State', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: confirmed without receipt'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET DeliveryState=''uncertain'',ConfirmedUTC=NULL,OwnerID=NULL', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: uncertain without owner', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceDelivery_State', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: uncertain without owner'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET Fence=0', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: zero fence', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceDelivery_State', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: zero fence'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourceDelivery SET UpdatedUTC=DATEADD(day,-1,CreatedUTC)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: time reversal', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourceDelivery_Time', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: time reversal'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET GovernorID=2', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: later-only player', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourcePlayerResult_Eligible', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: later-only player'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET RosterID=NEWID()', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: wrong roster member', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET CampID=2', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: wrong camp attribution', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'FK_SourcePlayerResult_Camp', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: wrong camp attribution'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dkp=CONVERT(decimal(38,6),''100000000000000000000000000000000'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp overflow', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'overflow', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp overflow'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.starting_power'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: starting_power absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_starting_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: starting_power absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.starting_power'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: starting_power status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_starting_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: starting_power status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET starting_power=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.starting_power'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: starting_power false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_starting_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: starting_power false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET starting_power_rank=2,starting_power_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: starting_power invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_starting_power_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: starting_power invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.power'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: power absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: power absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.power'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: power status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: power status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET power=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.power'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: power false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: power false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET power_rank=2,power_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: power invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_power_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: power invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.troops_power'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: troops_power absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_troops_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: troops_power absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.troops_power'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: troops_power status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_troops_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: troops_power status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET troops_power=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.troops_power'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: troops_power false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_troops_power', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: troops_power false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET troops_power_rank=2,troops_power_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: troops_power invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_troops_power_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: troops_power invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t1_kills'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t1_kills absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t1_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t1_kills absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t1_kills'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t1_kills status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t1_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t1_kills status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t1_kills=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t1_kills'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t1_kills false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t1_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t1_kills false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t1_kills_rank=2,t1_kills_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t1_kills invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t1_kills_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t1_kills invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t2_kills'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t2_kills absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t2_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t2_kills absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t2_kills'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t2_kills status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t2_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t2_kills status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t2_kills=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t2_kills'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t2_kills false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t2_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t2_kills false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t2_kills_rank=2,t2_kills_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t2_kills invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t2_kills_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t2_kills invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t3_kills'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t3_kills absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t3_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t3_kills absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t3_kills'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t3_kills status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t3_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t3_kills status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t3_kills=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t3_kills'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t3_kills false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t3_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t3_kills false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t3_kills_rank=2,t3_kills_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t3_kills invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t3_kills_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t3_kills invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t4_kills'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t4_kills absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t4_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t4_kills absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t4_kills'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t4_kills status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t4_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t4_kills status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t4_kills=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t4_kills'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t4_kills false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t4_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t4_kills false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t4_kills_rank=2,t4_kills_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t4_kills invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t4_kills_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t4_kills invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t5_kills'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t5_kills absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t5_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t5_kills absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t5_kills'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t5_kills status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t5_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t5_kills status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t5_kills=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.t5_kills'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t5_kills false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t5_kills', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t5_kills false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET t5_kills_rank=2,t5_kills_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: t5_kills invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_t5_kills_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: t5_kills invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.total_kill_points'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: total_kill_points absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_total_kill_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: total_kill_points absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.total_kill_points'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: total_kill_points status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_total_kill_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: total_kill_points status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET total_kill_points=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.total_kill_points'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: total_kill_points false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_total_kill_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: total_kill_points false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET total_kill_points_rank=2,total_kill_points_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: total_kill_points invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_total_kill_points_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: total_kill_points invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dead'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dead absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dead', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dead absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dead'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dead status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dead', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dead status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dead=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dead'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dead false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dead', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dead false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dead_rank=2,dead_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dead invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dead_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dead invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET healed=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET healed_rank=2,healed_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.acclaim'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: acclaim absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: acclaim absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.acclaim'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: acclaim status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: acclaim status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET acclaim=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.acclaim'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: acclaim false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: acclaim false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET acclaim_rank=2,acclaim_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: acclaim invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_acclaim_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: acclaim invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.highest_acclaim'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: highest_acclaim absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_highest_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: highest_acclaim absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.highest_acclaim'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: highest_acclaim status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_highest_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: highest_acclaim status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET highest_acclaim=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.highest_acclaim'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: highest_acclaim false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_highest_acclaim', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: highest_acclaim false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET highest_acclaim_rank=2,highest_acclaim_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: highest_acclaim invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_highest_acclaim_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: highest_acclaim invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.kp_t4_t5'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: kp_t4_t5 absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_kp_t4_t5', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: kp_t4_t5 absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.kp_t4_t5'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: kp_t4_t5 status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_kp_t4_t5', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: kp_t4_t5 status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET kp_t4_t5=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.kp_t4_t5'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: kp_t4_t5 false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_kp_t4_t5', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: kp_t4_t5 false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET kp_t4_t5_rank=2,kp_t4_t5_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: kp_t4_t5 invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_kp_t4_t5_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: kp_t4_t5 invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dkp=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dkp_rank=2,dkp_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed_points'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed_points absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed_points absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed_points'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed_points status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed_points status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET healed_points=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.healed_points'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed_points false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed_points', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed_points false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET healed_points_rank=2,healed_points_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: healed_points invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_healed_points_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: healed_points invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp_power_ratio'',NULL)', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp_power_ratio absent status', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp_power_ratio', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp_power_ratio absent status'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp_power_ratio'',''Available'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp_power_ratio status case', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp_power_ratio', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp_power_ratio status case'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dkp_power_ratio=0,FieldStatusJson=JSON_MODIFY(FieldStatusJson,''$.dkp_power_ratio'',''missing_end'')', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp_power_ratio false zero', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp_power_ratio', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp_power_ratio false zero'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
SAVE TRANSACTION ExpectedRejection;
BEGIN TRY
    EXEC sys.sp_executesql N'UPDATE KVK.SourcePlayerResult SET dkp_power_ratio_rank=2,dkp_power_ratio_cohort=1', N'@cfg uniqueidentifier,@cfg2 uniqueidentifier,@pub2 uniqueidentifier,@pub3 uniqueidentifier,@request uniqueidentifier,@overall uniqueidentifier,@season int,@utc datetime2(0)', @cfg=@cfg,@cfg2=@cfg2,@pub2=@pub2,@pub3=@pub3,@request=@request,@overall=@overall,@season=@season,@utc=@utc;
    THROW 51301, 'Accepted invalid case: dkp_power_ratio invalid cohort', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (547,2601,2627,8115) OR XACT_STATE() <> 1 THROW;
    IF CHARINDEX(N'CK_SourcePlayerResult_dkp_power_ratio_Rank', ERROR_MESSAGE()) = 0 BEGIN PRINT N'Unexpected constraint for: dkp_power_ratio invalid cohort'; THROW; END;
    ROLLBACK TRANSACTION ExpectedRejection;
    SET @Passed+=1;
END CATCH;
-- Exact representable limits and genuine zeros survive round trips; excess scale remains
-- an explicit S3B pre-binding validation obligation, not a CHECK-enforced precision claim.
UPDATE KVK.SourceWeightConfig SET WeightT4X=CONVERT(decimal(38,12),'99999999999999999999999999.999999999999'),WeightT4XSource='99999999999999999999999999.999999999999';
IF EXISTS (SELECT 1 FROM KVK.SourceWeightConfig WHERE WeightT4X<>CONVERT(decimal(38,12),'99999999999999999999999999.999999999999')) THROW 51300, 'Weight precision lost.', 1;
UPDATE KVK.SourcePlayerResult SET dkp=CONVERT(decimal(38,6),'99999999999999999999999999999999.999999'),t1_kills=9223372036854775807;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult WHERE dkp<>CONVERT(decimal(38,6),'99999999999999999999999999999999.999999')) THROW 51300, 'DKP precision lost.', 1;
UPDATE KVK.SourcePlayerResult SET dkp=0,dkp_rank=1,dkp_cohort=1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult WHERE starting_power<>0 OR dkp<>0 OR dkp_power_ratio IS NOT NULL) THROW 51300, 'Zero/absent metric semantics lost.', 1;
ROLLBACK TRANSACTION;
IF EXISTS (SELECT 1 FROM KVK.SourceArtifact) THROW 51300, 'Synthetic rows survived rollback: SourceArtifact', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceImportAttempt) THROW 51300, 'Synthetic rows survived rollback: SourceImportAttempt', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservation) THROW 51300, 'Synthetic rows survived rollback: SourceObservation', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceObservationRevision) THROW 51300, 'Synthetic rows survived rollback: SourceObservationRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerSnapshot) THROW 51300, 'Synthetic rows survived rollback: SourcePlayerSnapshot', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceLogicalScan) THROW 51300, 'Synthetic rows survived rollback: SourceLogicalScan', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRoster) THROW 51300, 'Synthetic rows survived rollback: SourceRoster', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRosterMember) THROW 51300, 'Synthetic rows survived rollback: SourceRosterMember', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateReport) THROW 51300, 'Synthetic rows survived rollback: SourceAggregateReport', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAggregateRevision) THROW 51300, 'Synthetic rows survived rollback: SourceAggregateRevision', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceKingdomReportRow) THROW 51300, 'Synthetic rows survived rollback: SourceKingdomReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampReportRow) THROW 51300, 'Synthetic rows survived rollback: SourceCampReportRow', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigVersion) THROW 51300, 'Synthetic rows survived rollback: SourceConfigVersion', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePeriod) THROW 51300, 'Synthetic rows survived rollback: SourcePeriod', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWindowConfig) THROW 51300, 'Synthetic rows survived rollback: SourceWindowConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceCampConfig) THROW 51300, 'Synthetic rows survived rollback: SourceCampConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceWeightConfig) THROW 51300, 'Synthetic rows survived rollback: SourceWeightConfig', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceScanBinding) THROW 51300, 'Synthetic rows survived rollback: SourceScanBinding', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceConfigRequest) THROW 51300, 'Synthetic rows survived rollback: SourceConfigRequest', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePublication) THROW 51300, 'Synthetic rows survived rollback: SourcePublication', 1;
IF EXISTS (SELECT 1 FROM KVK.SourcePlayerResult) THROW 51300, 'Synthetic rows survived rollback: SourcePlayerResult', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceSelection) THROW 51300, 'Synthetic rows survived rollback: SourceSelection', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceRouting) THROW 51300, 'Synthetic rows survived rollback: SourceRouting', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceAction) THROW 51300, 'Synthetic rows survived rollback: SourceAction', 1;
IF EXISTS (SELECT 1 FROM KVK.SourceDelivery) THROW 51300, 'Synthetic rows survived rollback: SourceDelivery', 1;
IF @Passed <> 144 THROW 51300, 'Not all rejection cases executed.', 1;
IF @WasXactAbort=1 SET XACT_ABORT ON;
IF @WasRoundAbort=1 SET NUMERIC_ROUNDABORT ON;
SELECT @Passed AS ExpectedRejectionsPassed, 25 AS EmptyTablesAfterRollback;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    IF @WasXactAbort=1 SET XACT_ABORT ON;
    IF @WasRoundAbort=1 SET NUMERIC_ROUNDABORT ON;
    THROW;
END CATCH;
