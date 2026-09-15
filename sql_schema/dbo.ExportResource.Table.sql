SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
CREATE TABLE dbo.ExportResource
(
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ResourceKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActiveJobID uniqueidentifier NULL,
    ActivePreparationID uniqueidentifier NULL,
    OwnerID uniqueidentifier NULL,
    Fence bigint NOT NULL,
    BlockedReason nvarchar(1024) NULL,
    Version bigint NOT NULL,
    CONSTRAINT PK_ExportResource PRIMARY KEY (ResourceKey),
    CONSTRAINT CK_ExportResource_Key CHECK (LEN(ResourceKey) > 0 AND DATALENGTH(ResourceKey) = DATALENGTH(LTRIM(RTRIM(ResourceKey)))),
    CONSTRAINT CK_ExportResource_Kind CHECK (DATALENGTH(ResourceKind) = LEN(ResourceKind) AND ResourceKind IN ('account','destination','sql_snapshot')),
    CONSTRAINT CK_ExportResource_Ownership CHECK ((ActiveJobID IS NULL AND ActivePreparationID IS NULL AND OwnerID IS NULL AND Fence >= 0) OR (ActiveJobID IS NOT NULL AND ActivePreparationID IS NULL AND OwnerID IS NOT NULL AND Fence > 0) OR (ActiveJobID IS NULL AND ActivePreparationID IS NOT NULL AND OwnerID IS NOT NULL AND Fence > 0)),
    CONSTRAINT CK_ExportResource_Blocked CHECK (BlockedReason IS NULL OR LEN(BlockedReason) > 0),
    CONSTRAINT CK_ExportResource_Version CHECK (Version > 0)
);
CREATE INDEX IX_ExportResource_ActiveJob ON dbo.ExportResource (ActiveJobID) WHERE ActiveJobID IS NOT NULL;
ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT FK_ExportResource_ActiveMembership FOREIGN KEY (ActiveJobID, ResourceKey) REFERENCES dbo.ExportJobResource (JobID, ResourceKey);

ALTER TABLE dbo.ExportResource WITH CHECK ADD CONSTRAINT FK_ExportResource_PreparationMembership FOREIGN KEY (ActivePreparationID,ResourceKey) REFERENCES dbo.ExportPreparationResource(PreparationID,ResourceKey);
