SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10E reference snapshot. Deploy the reviewed migration, not this file.
-- Shape only. DAL owns immutable facts, monotonic CAS, fair admission, termination
-- proof and provider evidence. Never release by lease age or job state alone.
CREATE TABLE KVK.SourceOutputOperationResource
(
    OperationID uniqueidentifier NOT NULL,
    PoolID uniqueidentifier NOT NULL,
    AccountKey varchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    IndexFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    SlotFileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NULL,
    CONSTRAINT PK_SourceOutputOperationResource PRIMARY KEY (OperationID, ResourceKey),
    CONSTRAINT UQ_SourceOutputOperationResource_File UNIQUE (OperationID, FileID),
    CONSTRAINT CK_SourceOutputOperationResource_Scope CHECK ((ResourceKind = 'account' AND DATALENGTH(ResourceKind) = 7 AND ResourceKey = 'account:' + AccountKey AND DATALENGTH(ResourceKey) = 8 + DATALENGTH(AccountKey) AND FileID IS NULL AND IndexFileID IS NULL AND SlotFileID IS NULL) OR (ResourceKind = 'destination' AND DATALENGTH(ResourceKind) = 11 AND FileID IS NOT NULL AND ResourceKey = 'destination:' + CONVERT(varchar(128),FileID) AND DATALENGTH(ResourceKey) = 12 + DATALENGTH(FileID) / 2 AND ((IndexFileID IS NOT NULL AND IndexFileID = FileID AND SlotFileID IS NULL) OR (SlotFileID IS NOT NULL AND SlotFileID = FileID AND IndexFileID IS NULL))))
);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Operation FOREIGN KEY (OperationID, PoolID, AccountKey) REFERENCES KVK.SourceOutputOperation (OperationID, PoolID, AccountKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_File FOREIGN KEY (FileID, ResourceKey) REFERENCES KVK.SourceOutputFile (FileID, ResourceKey);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Index FOREIGN KEY (PoolID, IndexFileID) REFERENCES KVK.SourceOutputPool (PoolID, IndexFileID);
ALTER TABLE KVK.SourceOutputOperationResource WITH CHECK ADD CONSTRAINT FK_SourceOutputOperationResource_Slot FOREIGN KEY (PoolID, SlotFileID) REFERENCES KVK.SourceOutputSlot (PoolID, FileID);
