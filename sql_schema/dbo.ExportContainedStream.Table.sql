SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Original stream version and ledger seal retained separately from logical closure.
CREATE TABLE dbo.ExportContainedStream
(
 StreamID uniqueidentifier NOT NULL,
 ContainmentID uniqueidentifier NOT NULL,
 OriginalVersion bigint NOT NULL,
 LastSequence bigint NOT NULL,
 EventDigest binary(32) NOT NULL,
 CONSTRAINT PK_ExportContainedStream PRIMARY KEY (StreamID),
 CONSTRAINT CK_ExportContainedStream_Counters CHECK (OriginalVersion>0 AND LastSequence>=0),
 CONSTRAINT FK_ExportContainedStream_Decision FOREIGN KEY (ContainmentID) REFERENCES dbo.ExportTargetContainment(ContainmentID),
 CONSTRAINT FK_ExportContainedStream_Stream FOREIGN KEY (StreamID) REFERENCES dbo.ExportExecutionStream(StreamID)
);
