SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputOperationResource](
	[OperationID] [uniqueidentifier] NOT NULL,
	[PoolID] [uniqueidentifier] NOT NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ResourceKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[FileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[IndexFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[SlotFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
 CONSTRAINT [PK_SourceOutputOperationResource] PRIMARY KEY CLUSTERED 
(
	[OperationID] ASC,
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputOperationResource_File] UNIQUE NONCLUSTERED 
(
	[OperationID] ASC,
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperationResource_File] FOREIGN KEY([FileID], [ResourceKey])
REFERENCES [KVK].[SourceOutputFile] ([FileID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [FK_SourceOutputOperationResource_File]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperationResource_Index] FOREIGN KEY([PoolID], [IndexFileID])
REFERENCES [KVK].[SourceOutputPool] ([PoolID], [IndexFileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [FK_SourceOutputOperationResource_Index]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Operation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperationResource_Operation] FOREIGN KEY([OperationID], [PoolID], [AccountKey])
REFERENCES [KVK].[SourceOutputOperation] ([OperationID], [PoolID], [AccountKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Operation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [FK_SourceOutputOperationResource_Operation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperationResource_Resource] FOREIGN KEY([ResourceKey])
REFERENCES [dbo].[ExportResource] ([ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [FK_SourceOutputOperationResource_Resource]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Slot]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperationResource_Slot] FOREIGN KEY([PoolID], [SlotFileID])
REFERENCES [KVK].[SourceOutputSlot] ([PoolID], [FileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperationResource_Slot]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [FK_SourceOutputOperationResource_Slot]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperationResource_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperationResource_Scope] CHECK  (([ResourceKind]='account' AND datalength([ResourceKind])=(7) AND [ResourceKey]=('account:'+[AccountKey]) AND datalength([ResourceKey])=((8)+datalength([AccountKey])) AND [FileID] IS NULL AND [IndexFileID] IS NULL AND [SlotFileID] IS NULL OR [ResourceKind]='destination' AND datalength([ResourceKind])=(11) AND [FileID] IS NOT NULL AND [ResourceKey]=('destination:'+CONVERT([varchar](128),[FileID])) AND datalength([ResourceKey])=((12)+datalength([FileID])/(2)) AND ([IndexFileID] IS NOT NULL AND [IndexFileID]=[FileID] AND [SlotFileID] IS NULL OR [SlotFileID] IS NOT NULL AND [SlotFileID]=[FileID] AND [IndexFileID] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperationResource_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperationResource]'))
ALTER TABLE [KVK].[SourceOutputOperationResource] CHECK CONSTRAINT [CK_SourceOutputOperationResource_Scope]
