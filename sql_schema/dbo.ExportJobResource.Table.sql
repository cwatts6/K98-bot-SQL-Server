SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S10A reference snapshot. Deploy the reviewed migration, not this file.
-- Static shape only: authorized later DAL owns CAS, transitions, immutable inputs,
-- fairness, resource acquisition/release and provider evidence validation.
-- For snapshot reconstruction create all six tables before adding the ownership FKs.
CREATE TABLE dbo.ExportJobResource
(
    JobID uniqueidentifier NOT NULL,
    ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
    CONSTRAINT PK_ExportJobResource PRIMARY KEY (JobID, ResourceKey)
);
CREATE INDEX IX_ExportJobResource_Resource ON dbo.ExportJobResource (ResourceKey, JobID);
ALTER TABLE dbo.ExportJobResource WITH CHECK ADD CONSTRAINT FK_ExportJobResource_Job FOREIGN KEY (JobID) REFERENCES dbo.ExportJob (JobID);
ALTER TABLE dbo.ExportJobResource WITH CHECK ADD CONSTRAINT FK_ExportJobResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource (ResourceKey);
