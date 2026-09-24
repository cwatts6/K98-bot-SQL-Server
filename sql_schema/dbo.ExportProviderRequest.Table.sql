SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
CREATE TABLE dbo.ExportProviderRequest
(
RequestID uniqueidentifier NOT NULL,
 StreamID uniqueidentifier NOT NULL,
 Sequence bigint NOT NULL,
 Operation varchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestKind varchar(16) COLLATE Latin1_General_100_BIN2 NOT NULL,
 TargetID varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 PayloadHash binary(32) NOT NULL,
 PayloadReference uniqueidentifier NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportProviderRequest PRIMARY KEY (RequestID),
 CONSTRAINT UQ_ExportProviderRequest_Sequence UNIQUE (StreamID,Sequence),
 CONSTRAINT FK_ExportProviderRequest_Stream FOREIGN KEY (StreamID) REFERENCES dbo.ExportExecutionStream(StreamID),
 CONSTRAINT CK_ExportProviderRequest_Sequence CHECK (Sequence>0),
 CONSTRAINT CK_ExportProviderRequest_Target CHECK (LEN(TargetID)>0 AND DATALENGTH(TargetID)=LEN(TargetID) AND TargetID NOT LIKE '%[^A-Za-z0-9_-]%' COLLATE Latin1_General_100_BIN2),
 CONSTRAINT CK_ExportProviderRequest_Operation CHECK (DATALENGTH(Operation)=LEN(Operation) AND DATALENGTH(RequestKind)=LEN(RequestKind) AND ((RequestKind='read' AND Operation IN ('sheets.get','sheets.values.get','sheets.values.batchGet','drive.files.get','drive.permissions.list')) OR (RequestKind='mutation' AND Operation IN ('sheets.batchUpdate','sheets.values.update','sheets.values.clear','drive.files.update','drive.permissions.create','drive.permissions.delete','sheets.create'))))
);
