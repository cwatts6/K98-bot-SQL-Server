SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportExecutionSession
(
SessionID uniqueidentifier NOT NULL,
 AuthorityPrincipal nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 HostIdentity varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 BootID uniqueidentifier NOT NULL,
 ExecutableHash binary(32) NOT NULL,
 ManifestHash binary(32) NOT NULL,
 ProtocolVersion int NOT NULL,
 State varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 Version bigint NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 ClosedUTC datetime2(3) NULL,
 CONSTRAINT PK_ExportExecutionSession PRIMARY KEY (SessionID),
 CONSTRAINT CK_ExportExecutionSession_Identity CHECK (LEN(AuthorityPrincipal)>0 AND LEN(HostIdentity)>0 AND DATALENGTH(HostIdentity)=LEN(HostIdentity) AND HostIdentity NOT LIKE '%[^A-Za-z0-9_.:-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportExecutionSession_Version CHECK (ProtocolVersion=1 AND Version>0),
 CONSTRAINT CK_ExportExecutionSession_State CHECK (DATALENGTH(State)=LEN(State) AND ((State='open' AND ClosedUTC IS NULL) OR (State='closed' AND ClosedUTC>=CreatedUTC)))
);
