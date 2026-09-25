SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportExecutionStream
(
StreamID uniqueidentifier NOT NULL,
 SessionID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ActiveAccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 JobID uniqueidentifier NULL,
 PreparationID uniqueidentifier NULL,
 OutputOperationID uniqueidentifier NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 ClaimVersion bigint NOT NULL,
 NestedToken uniqueidentifier NULL,
 RegistrationHash binary(32) NOT NULL,
 Epoch bigint NULL,
 SnapshotHash binary(32) NOT NULL,
 ScopeJson nvarchar(max) NOT NULL,
 Purpose varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 LastSequence bigint NOT NULL,
 ChildIdentity uniqueidentifier NOT NULL,
 ClosureHash binary(32) NULL,
 ClosureReference uniqueidentifier NULL,
 EventDigest binary(32) NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 CONSTRAINT PK_ExportExecutionStream PRIMARY KEY (StreamID),
 CONSTRAINT UQ_ExportExecutionStream_Session UNIQUE (StreamID,SessionID),
 CONSTRAINT FK_ExportExecutionStream_Session FOREIGN KEY (SessionID) REFERENCES dbo.ExportExecutionSession(SessionID),
 CONSTRAINT FK_ExportExecutionStream_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID),
 CONSTRAINT FK_ExportExecutionStream_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportExecutionStream_Operation FOREIGN KEY (OutputOperationID) REFERENCES KVK.SourceOutputOperation(OperationID),
 CONSTRAINT CK_ExportExecutionStream_Owner CHECK ((CASE WHEN JobID IS NULL THEN 0 ELSE 1 END + CASE WHEN PreparationID IS NULL THEN 0 ELSE 1 END + CASE WHEN OutputOperationID IS NULL THEN 0 ELSE 1 END)=1 AND (NestedToken IS NULL OR JobID IS NOT NULL)),
 CONSTRAINT CK_ExportExecutionStream_Account CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=LEN(AccountKey) AND AccountKey NOT LIKE '%[^A-Za-z0-9_.@:-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportExecutionStream_Counters CHECK (ClaimVersion>0 AND Version>0 AND LastSequence>=0 AND (Epoch IS NULL OR Epoch>0) AND ((OwnerID IS NOT NULL AND Fence>0) OR (OwnerID IS NULL AND Fence=0 AND OutputOperationID IS NOT NULL AND Purpose='probe' AND NestedToken IS NULL))),
 CONSTRAINT CK_ExportExecutionStream_Purpose CHECK (Purpose IN ('mutation','probe','enrollment') AND DATALENGTH(Purpose)=LEN(Purpose)),
 CONSTRAINT CK_ExportExecutionStream_State CHECK (DATALENGTH(State)=LEN(State) AND ((State IN ('open','frozen') AND ActiveAccountKey IS NOT NULL AND ActiveAccountKey=AccountKey AND DATALENGTH(ActiveAccountKey)=DATALENGTH(AccountKey) AND ClosedUTC IS NULL AND ClosureHash IS NULL AND ClosureReference IS NULL AND EventDigest IS NULL) OR (State='closed' AND ActiveAccountKey IS NULL AND ClosedUTC>=CreatedUTC AND ClosureHash IS NOT NULL AND ClosureReference IS NOT NULL AND EventDigest IS NOT NULL))),
 CONSTRAINT CK_ExportExecutionStream_Scope CHECK (ISJSON(ScopeJson)=1 AND DATALENGTH(ScopeJson)<=65536)
);
CREATE UNIQUE INDEX UX_ExportExecutionStream_ActiveAccount ON dbo.ExportExecutionStream(ActiveAccountKey) WHERE ActiveAccountKey IS NOT NULL;
CREATE INDEX IX_ExportExecutionStream_Owner ON dbo.ExportExecutionStream(AccountKey,JobID,PreparationID,OutputOperationID,State);
CREATE INDEX IX_ExportExecutionStream_Session ON dbo.ExportExecutionStream(SessionID,State);
