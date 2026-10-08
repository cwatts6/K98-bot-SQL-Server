SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceArtifact]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceArtifact](
	[ArtifactHash] [binary](32) NOT NULL,
	[ByteCount] [bigint] NOT NULL,
	[StorageKey] [nvarchar](512) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceArtifact] PRIMARY KEY CLUSTERED 
(
	[ArtifactHash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceArtifact_Bytes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceArtifact]'))
ALTER TABLE [KVK].[SourceArtifact]  WITH CHECK ADD  CONSTRAINT [CK_SourceArtifact_Bytes] CHECK  (([ByteCount]>(0) AND [ByteCount]<=(20971520)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceArtifact_Bytes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceArtifact]'))
ALTER TABLE [KVK].[SourceArtifact] CHECK CONSTRAINT [CK_SourceArtifact_Bytes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceArtifact_Storage]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceArtifact]'))
ALTER TABLE [KVK].[SourceArtifact]  WITH CHECK ADD  CONSTRAINT [CK_SourceArtifact_Storage] CHECK  (([StorageKey]=(lower(CONVERT([varchar](64),[ArtifactHash],(2)))+N'.xlsx') AND datalength([StorageKey])=(138)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceArtifact_Storage]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceArtifact]'))
ALTER TABLE [KVK].[SourceArtifact] CHECK CONSTRAINT [CK_SourceArtifact_Storage]
