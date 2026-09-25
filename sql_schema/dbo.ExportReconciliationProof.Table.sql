SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportReconciliationProof
(
ProofID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 SnapshotHash binary(32) NOT NULL,
 RegistrationHash binary(32) NOT NULL,
 ProofKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Outcome varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 MembershipHash binary(32) NOT NULL,
 MembershipJson nvarchar(max) NOT NULL,
 EvidenceJson nvarchar(max) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportReconciliationProof PRIMARY KEY (ProofID),
 CONSTRAINT FK_ExportReconciliationProof_Session FOREIGN KEY (SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT CK_ExportReconciliationProof_Kind CHECK (DATALENGTH(ProofKind)=LEN(ProofKind) AND ProofKind IN ('publication','retirement','retirement_recovery','rollover_drain','rollover_complete')),
 CONSTRAINT CK_ExportReconciliationProof_Outcome CHECK (DATALENGTH(Outcome)=LEN(Outcome) AND ((ProofKind='publication' AND Outcome IN ('confirmed','absent','damaged')) OR (ProofKind IN ('retirement','retirement_recovery','rollover_drain') AND Outcome='confirmed') OR (ProofKind='rollover_complete' AND Outcome='completed'))),
 CONSTRAINT CK_ExportReconciliationProof_Account CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportReconciliationProof_Evidence CHECK (ISJSON(MembershipJson)=1 AND DATALENGTH(MembershipJson)<=65536 AND ISJSON(EvidenceJson)=1 AND DATALENGTH(EvidenceJson)<=65536)
);
CREATE INDEX IX_ExportReconciliationProof_Snapshot ON dbo.ExportReconciliationProof(AccountKey,SnapshotHash,ProofKind);
