SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportProviderRequestEvent
(
EventID uniqueidentifier NOT NULL,
 RequestID uniqueidentifier NOT NULL,
 EventSequence int NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 EvidenceHash binary(32) NOT NULL,
 EvidenceReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportProviderRequestEvent PRIMARY KEY (EventID),
 CONSTRAINT UQ_ExportProviderRequestEvent_Sequence UNIQUE (RequestID,EventSequence),
 CONSTRAINT FK_ExportProviderRequestEvent_Request FOREIGN KEY (RequestID) REFERENCES dbo.ExportProviderRequest(RequestID),
 CONSTRAINT CK_ExportProviderRequestEvent_State CHECK (DATALENGTH(State)=LEN(State) AND ((EventSequence=1 AND State='prepared') OR (EventSequence=2 AND State IN ('dispatch_intent','not_sent')) OR (EventSequence=3 AND State IN ('succeeded','unknown'))))
);
