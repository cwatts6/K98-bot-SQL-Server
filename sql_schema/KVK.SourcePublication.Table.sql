SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2B reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourcePublication
(
    PublicationID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    PeriodID uniqueidentifier NOT NULL,
    PeriodKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Generation bigint NOT NULL,
    ConfigVersionID uniqueidentifier NOT NULL,
    RosterID uniqueidentifier NOT NULL,
    CalculationVersion varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StartScanID int NULL,
    EndScanID int NULL,
    StartRevisionID uniqueidentifier NULL,
    EndRevisionID uniqueidentifier NULL,
    AggregateReportID uniqueidentifier NULL,
    AggregateRevisionID uniqueidentifier NULL,
    PlayerState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    AggregateState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PeriodState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    BuildState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    EligibleCount int NOT NULL,
    ResultCount int NOT NULL,
    KingdomCount int NOT NULL,
    CampCount int NOT NULL,
    ManifestHash binary(32) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    CompletedUTC datetime2(0) NULL,
    FinalUnavailableReason nvarchar(1024) NULL,
    CONSTRAINT PK_SourcePublication PRIMARY KEY (PublicationID),
    CONSTRAINT UQ_SourcePublication_Generation UNIQUE (SourceKey, KVK_NO, PeriodID, Generation),
    CONSTRAINT UQ_SourcePublication_Scope UNIQUE (SourceKey, KVK_NO, PeriodID, PublicationID),
    CONSTRAINT UQ_SourcePublication_Config UNIQUE (SourceKey, KVK_NO, PeriodID, ConfigVersionID, PublicationID),
    CONSTRAINT UQ_SourcePublication_Result UNIQUE (SourceKey, KVK_NO, PublicationID, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourcePublication_Period FOREIGN KEY (SourceKey, KVK_NO, PeriodID, PeriodKey) REFERENCES KVK.SourcePeriod (SourceKey, KVK_NO, PeriodID, PeriodKey),
    CONSTRAINT FK_SourcePublication_Window FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, PeriodKey) REFERENCES KVK.SourceWindowConfig (SourceKey, KVK_NO, ConfigVersionID, PeriodKey),
    CONSTRAINT FK_SourcePublication_ConfigRoster FOREIGN KEY (SourceKey, KVK_NO, ConfigVersionID, RosterID) REFERENCES KVK.SourceConfigVersion (SourceKey, KVK_NO, ConfigVersionID, RosterID),
    CONSTRAINT FK_SourcePublication_StartBinding FOREIGN KEY (ConfigVersionID, StartScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourcePublication_EndBinding FOREIGN KEY (ConfigVersionID, EndScanID) REFERENCES KVK.SourceScanBinding (ConfigVersionID, LogicalScanID),
    CONSTRAINT FK_SourcePublication_StartRevision FOREIGN KEY (SourceKey, KVK_NO, StartRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourcePublication_EndRevision FOREIGN KEY (SourceKey, KVK_NO, EndRevisionID) REFERENCES KVK.SourceObservationRevision (SourceKey, KVK_NO, RevisionID),
    CONSTRAINT FK_SourcePublication_Aggregate FOREIGN KEY (SourceKey, KVK_NO, AggregateReportID, AggregateRevisionID) REFERENCES KVK.SourceAggregateRevision (SourceKey, KVK_NO, ReportID, RevisionID),
    CONSTRAINT CK_SourcePublication_Counts CHECK (Generation > 0 AND EligibleCount BETWEEN 1 AND 50000 AND ResultCount BETWEEN 0 AND EligibleCount AND KingdomCount BETWEEN 0 AND 512 AND CampCount BETWEEN 0 AND 8 AND LEN(CalculationVersion) > 0),
    CONSTRAINT CK_SourcePublication_Inputs CHECK (((StartScanID IS NULL AND StartRevisionID IS NULL) OR (StartScanID IS NOT NULL AND StartRevisionID IS NOT NULL)) AND ((EndScanID IS NULL AND EndRevisionID IS NULL) OR (EndScanID IS NOT NULL AND EndRevisionID IS NOT NULL)) AND ((AggregateReportID IS NULL AND AggregateRevisionID IS NULL) OR (AggregateReportID IS NOT NULL AND AggregateRevisionID IS NOT NULL))),
    CONSTRAINT CK_SourcePublication_Player CHECK (DATALENGTH(PlayerState) = LEN(PlayerState) AND ((PlayerState IN ('live','final','corrected_final','not_applicable') AND StartRevisionID IS NOT NULL AND EndRevisionID IS NOT NULL) OR PlayerState IN ('missing_start','missing_end','missing_configuration','validation_failed','not_received','final_unavailable'))),
    CONSTRAINT CK_SourcePublication_AggregateState CHECK (DATALENGTH(AggregateState) = LEN(AggregateState) AND ((AggregateState IN ('live','final','corrected_final') AND AggregateRevisionID IS NOT NULL) OR (AggregateState IN ('not_received','validation_failed','not_applicable','final_unavailable') AND AggregateRevisionID IS NULL))),
    -- An unavailable reason cannot finalize a live or merely missing component.
    -- Authorization of the explicit terminal designation is enforced by the later S3B writer.
    CONSTRAINT CK_SourcePublication_Final CHECK (
        DATALENGTH(PeriodState) = LEN(PeriodState) AND PeriodState IN ('live','final','corrected_final')
        AND ((PlayerState <> 'final_unavailable' AND AggregateState <> 'final_unavailable')
             OR (FinalUnavailableReason IS NOT NULL AND LEN(FinalUnavailableReason) > 0))
        AND (PeriodState = 'live'
             OR (PlayerState IN ('final','corrected_final','not_applicable','final_unavailable')
                 AND AggregateState IN ('final','corrected_final','not_applicable','final_unavailable')))),
    CONSTRAINT CK_SourcePublication_Build CHECK (DATALENGTH(BuildState) = LEN(BuildState) AND ((BuildState = 'building' AND CompletedUTC IS NULL) OR (BuildState = 'complete' AND CompletedUTC IS NOT NULL AND ManifestHash IS NOT NULL AND ResultCount = EligibleCount)) AND (CompletedUTC IS NULL OR CompletedUTC >= CreatedUTC)),
    CONSTRAINT CK_SourcePublication_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0)
);
