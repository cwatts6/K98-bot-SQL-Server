SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputFile](
	[FileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[FileKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RegisteredBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RegisteredUTC] [datetime2](0) NOT NULL,
	[EvidenceHash] [binary](32) NOT NULL,
	[EvidenceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceOutputFile] PRIMARY KEY CLUSTERED 
(
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputFile_Kind] UNIQUE NONCLUSTERED 
(
	[FileID] ASC,
	[FileKind] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputFile_Resource] UNIQUE NONCLUSTERED 
(
	[FileID] ASC,
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputFile_ResourceKey] UNIQUE NONCLUSTERED 
(
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputFile_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputFile_Resource] FOREIGN KEY([ResourceKey])
REFERENCES [dbo].[ExportResource] ([ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputFile_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [FK_SourceOutputFile_Resource]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputFile_Actor] CHECK  ((len([RegisteredBy])>(0) AND datalength([RegisteredBy])=datalength(ltrim(rtrim([RegisteredBy])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [CK_SourceOutputFile_Actor]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputFile_Evidence] CHECK  ((isjson([EvidenceJson])=(1) AND datalength([EvidenceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [CK_SourceOutputFile_Evidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputFile_Identity] CHECK  ((datalength([FileID])>=(6) AND datalength([FileID])<=(256) AND NOT [FileID] like (N'%[^-A-Za-z0-9_]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [CK_SourceOutputFile_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputFile_Kind] CHECK  ((([FileKind]='slot' OR [FileKind]='index') AND datalength([FileKind])=len([FileKind])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [CK_SourceOutputFile_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputFile_Resource] CHECK  (([ResourceKey]=('destination:'+CONVERT([varchar](128),[FileID])) AND datalength([ResourceKey])=((12)+datalength([FileID])/(2))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputFile_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputFile]'))
ALTER TABLE [KVK].[SourceOutputFile] CHECK CONSTRAINT [CK_SourceOutputFile_Resource]
