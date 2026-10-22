SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
CREATE TABLE dbo.ExportUnownedHoldDisposition
(
    ActionID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    StorageOwner varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ReviewHash binary(32) NOT NULL,
    BeforeJson nvarchar(max) NOT NULL,
    AfterVersion bigint NOT NULL,
    Actor nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Reason nvarchar(512) NOT NULL,
    CreatedUTC datetime2(3) NOT NULL CONSTRAINT DF_UnownedHoldDisposition_Created DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ExportUnownedHoldDisposition PRIMARY KEY(ActionID),
    CONSTRAINT CK_UnownedHoldDisposition_Resource CHECK(ResourceKey='sql_snapshot:legacy_outputs'),
    CONSTRAINT CK_UnownedHoldDisposition_Json CHECK(ISJSON(BeforeJson)=1 AND DATALENGTH(BeforeJson)<=16384),
    CONSTRAINT CK_UnownedHoldDisposition_Text CHECK(LEN(AccountKey)>0 AND LEN(StorageOwner)>0 AND LEN(Actor)>0 AND LEN(Reason)>0),
    CONSTRAINT CK_UnownedHoldDisposition_Version CHECK(AfterVersion>1),
    CONSTRAINT UQ_UnownedHoldDisposition_Version UNIQUE(ResourceKey,AfterVersion)
);
CREATE INDEX IX_UnownedHoldDisposition_Account ON dbo.ExportUnownedHoldDisposition(AccountKey,StorageOwner,AfterVersion);
