SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S2A reference snapshot; deploy the reviewed migration, not this file.
CREATE TABLE KVK.SourceRosterMember
(
    RosterID uniqueidentifier NOT NULL,
    SourceKey varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    KVK_NO int NOT NULL,
    GovernorID bigint NOT NULL,
    b0_kingdom int NOT NULL,
    b0_power bigint NULL,
    CONSTRAINT PK_SourceRosterMember PRIMARY KEY (RosterID, GovernorID),
    CONSTRAINT FK_SourceRosterMember_Roster FOREIGN KEY (SourceKey, KVK_NO, RosterID) REFERENCES KVK.SourceRoster (SourceKey, KVK_NO, RosterID),
    CONSTRAINT CK_SourceRosterMember_Scope CHECK (SourceKey = 'snapshot_report_v1' AND DATALENGTH(SourceKey) = 18 AND KVK_NO > 0),
    CONSTRAINT CK_SourceRosterMember_Identity CHECK (GovernorID > 0 AND b0_kingdom > 0 AND (b0_power IS NULL OR b0_power >= 0))
);
