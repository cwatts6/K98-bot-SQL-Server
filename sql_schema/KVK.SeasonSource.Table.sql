SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S8A reference snapshot; deploy the reviewed migration, not this file.
-- SQL enforces static scope, shape and uniqueness, not temporal immutability or eligibility.
-- S8B alone supplies authorized writer APIs, CAS, lock ordering and atomic public intent.
CREATE TABLE KVK.SeasonSource
(
    KVK_NO int NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChoiceID uniqueidentifier NOT NULL,
    ChosenBy nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChosenUTC datetime2(0) NOT NULL,
    Reason nvarchar(1024) NOT NULL,
    ProvenanceJson nvarchar(max) NOT NULL,
    SeasonState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    SeasonVersion bigint NOT NULL,
    CONSTRAINT PK_SeasonSource PRIMARY KEY (KVK_NO),
    CONSTRAINT UQ_SeasonSource_Choice UNIQUE (KVK_NO, SourceKey, ChoiceID),
    CONSTRAINT CK_SeasonSource_Scope CHECK (KVK_NO > 0 AND ((SourceKey = 'legacy_full_data' AND DATALENGTH(SourceKey) = 16) OR (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18))),
    CONSTRAINT CK_SeasonSource_State CHECK (DATALENGTH(SeasonState) = LEN(SeasonState) AND SeasonState IN ('planned','open','closing','closed') AND SeasonVersion > 0),
    CONSTRAINT CK_SeasonSource_Provenance CHECK (LEN(ChosenBy) > 0 AND LEN(Reason) > 0 AND ISJSON(ProvenanceJson) = 1 AND DATALENGTH(ProvenanceJson) <= 65536)
);
