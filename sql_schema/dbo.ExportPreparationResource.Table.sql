SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- Immutable membership history. Active ownership is on ExportResource.
CREATE TABLE dbo.ExportPreparationResource
(
 PreparationID uniqueidentifier NOT NULL,
 ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT PK_ExportPreparationResource PRIMARY KEY (PreparationID,ResourceKey),
 CONSTRAINT FK_ExportPreparationResource_Preparation FOREIGN KEY (PreparationID) REFERENCES dbo.ExportPreparation(PreparationID),
 CONSTRAINT FK_ExportPreparationResource_Resource FOREIGN KEY (ResourceKey) REFERENCES dbo.ExportResource(ResourceKey)
);
CREATE INDEX IX_ExportPreparationResource_Resource ON dbo.ExportPreparationResource(ResourceKey);
