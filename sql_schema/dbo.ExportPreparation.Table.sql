SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10C reference snapshot. Deploy the reviewed migration, never this file.
CREATE TABLE dbo.ExportPreparation
(
 PreparationID uniqueidentifier NOT NULL,
 AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 ConsumerKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 KVK_NO int NULL,
 RequestHash binary(32) NOT NULL,
 EnqueueSequence bigint NOT NULL,
 State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 OwnerID uniqueidentifier NULL,
 Fence bigint NOT NULL,
 Version bigint NOT NULL,
 StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 RequestJson nvarchar(max) NOT NULL,
 GenerationJson nvarchar(max) NULL,
 SpoolKey varchar(128) COLLATE Latin1_General_100_BIN2 NULL,
 SpoolBytes bigint NULL,
 SpoolHash binary(32) NULL,
 JobID uniqueidentifier NULL,
 Actor nvarchar(128) NOT NULL,
 Reason nvarchar(1024) NOT NULL,
 CreatedUTC datetime2(3) NOT NULL,
 UpdatedUTC datetime2(3) NOT NULL,
 CONSTRAINT PK_ExportPreparation PRIMARY KEY (PreparationID),
 CONSTRAINT UQ_ExportPreparation_Replay UNIQUE (AccountKey,RequestHash),
 CONSTRAINT CK_ExportPreparation_Consumer CHECK (ConsumerKind IN ('all_kvk','scan_data','config') AND DATALENGTH(ConsumerKind)=LEN(ConsumerKind)),
 CONSTRAINT CK_ExportPreparation_Scope CHECK ((ConsumerKind='all_kvk' AND KVK_NO IS NOT NULL AND KVK_NO>0) OR (ConsumerKind IN ('scan_data','config') AND KVK_NO IS NULL)),
 CONSTRAINT CK_ExportPreparation_State CHECK (State IN ('pending','preflight','sql_pending','writing','committed','captured','materialized','completed','unavailable','uncertain') AND DATALENGTH(State)=LEN(State)),
 CONSTRAINT CK_ExportPreparation_Owner CHECK ((OwnerID IS NULL AND Fence=0 AND State='pending') OR (OwnerID IS NOT NULL AND Fence>0)),
 CONSTRAINT CK_ExportPreparation_Counters CHECK (Version>0 AND EnqueueSequence>0 AND UpdatedUTC>=CreatedUTC),
 CONSTRAINT CK_ExportPreparation_Text CHECK (LEN(AccountKey)>0 AND DATALENGTH(AccountKey)=DATALENGTH(LTRIM(RTRIM(AccountKey))) AND LEN(StorageOwner)>0 AND DATALENGTH(StorageOwner)=DATALENGTH(LTRIM(RTRIM(StorageOwner))) AND LEN(Actor)>0 AND LEN(Reason)>0),
 CONSTRAINT CK_ExportPreparation_Request CHECK (ISJSON(RequestJson)=1 AND DATALENGTH(RequestJson)<=65536),
 CONSTRAINT CK_ExportPreparation_Generation CHECK ((GenerationJson IS NULL AND State NOT IN ('committed','captured','materialized')) OR (GenerationJson IS NOT NULL AND ISJSON(GenerationJson)=1 AND DATALENGTH(GenerationJson)<=65536)),
 CONSTRAINT CK_ExportPreparation_Spool CHECK ((SpoolKey IS NULL AND SpoolBytes IS NULL AND SpoolHash IS NULL AND State NOT IN ('captured','materialized')) OR (SpoolKey IS NOT NULL AND SpoolBytes IS NOT NULL AND SpoolHash IS NOT NULL AND SpoolBytes>0 AND LEN(SpoolKey)>0 AND DATALENGTH(SpoolKey)=DATALENGTH(LTRIM(RTRIM(SpoolKey))) AND SpoolKey NOT LIKE '%[^a-zA-Z0-9_-]%' COLLATE Latin1_General_100_BIN2)),
 CONSTRAINT CK_ExportPreparation_Job CHECK ((JobID IS NULL AND State<>'materialized') OR (JobID IS NOT NULL AND State='materialized' AND ConsumerKind<>'config')),
 CONSTRAINT FK_ExportPreparation_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob(JobID)
);
CREATE INDEX IX_ExportPreparation_Queue ON dbo.ExportPreparation(AccountKey,State,EnqueueSequence,PreparationID);
CREATE UNIQUE INDEX UX_ExportPreparation_Job ON dbo.ExportPreparation(JobID) WHERE JobID IS NOT NULL;
