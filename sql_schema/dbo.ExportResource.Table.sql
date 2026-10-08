SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportResource]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportResource](
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ResourceKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActiveJobID] [uniqueidentifier] NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[BlockedReason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
	[Version] [bigint] NOT NULL,
	[ActivePreparationID] [uniqueidentifier] NULL,
	[ActiveOutputOperationID] [uniqueidentifier] NULL,
 CONSTRAINT [PK_ExportResource] PRIMARY KEY CLUSTERED 
(
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportResource]') AND name = N'IX_ExportResource_ActiveJob')
CREATE NONCLUSTERED INDEX [IX_ExportResource_ActiveJob] ON [dbo].[ExportResource]
(
	[ActiveJobID] ASC
)
WHERE ([ActiveJobID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportResource]') AND name = N'IX_ExportResource_ActiveOutputOperation')
CREATE NONCLUSTERED INDEX [IX_ExportResource_ActiveOutputOperation] ON [dbo].[ExportResource]
(
	[ActiveOutputOperationID] ASC
)
WHERE ([ActiveOutputOperationID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_ActiveMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportResource_ActiveMembership] FOREIGN KEY([ActiveJobID], [ResourceKey])
REFERENCES [dbo].[ExportJobResource] ([JobID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_ActiveMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [FK_ExportResource_ActiveMembership]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_OutputOperationMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportResource_OutputOperationMembership] FOREIGN KEY([ActiveOutputOperationID], [ResourceKey])
REFERENCES [KVK].[SourceOutputOperationResource] ([OperationID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_OutputOperationMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [FK_ExportResource_OutputOperationMembership]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_PreparationMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportResource_PreparationMembership] FOREIGN KEY([ActivePreparationID], [ResourceKey])
REFERENCES [dbo].[ExportPreparationResource] ([PreparationID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportResource_PreparationMembership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [FK_ExportResource_PreparationMembership]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Blocked]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [CK_ExportResource_Blocked] CHECK  (([BlockedReason] IS NULL OR len([BlockedReason])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Blocked]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [CK_ExportResource_Blocked]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Key]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [CK_ExportResource_Key] CHECK  ((len([ResourceKey])>(0) AND datalength([ResourceKey])=datalength(ltrim(rtrim([ResourceKey])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Key]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [CK_ExportResource_Key]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Kind]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [CK_ExportResource_Kind] CHECK  ((datalength([ResourceKind])=len([ResourceKind]) AND ([ResourceKind]='sql_snapshot' OR [ResourceKind]='destination' OR [ResourceKind]='account')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Kind]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [CK_ExportResource_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Ownership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [CK_ExportResource_Ownership] CHECK  (([ActiveJobID] IS NULL AND [ActivePreparationID] IS NULL AND [ActiveOutputOperationID] IS NULL AND [OwnerID] IS NULL AND [Fence]>=(0) OR [ActiveJobID] IS NOT NULL AND [ActivePreparationID] IS NULL AND [ActiveOutputOperationID] IS NULL AND [OwnerID] IS NOT NULL AND [Fence]>(0) OR [ActiveJobID] IS NULL AND [ActivePreparationID] IS NOT NULL AND [ActiveOutputOperationID] IS NULL AND [OwnerID] IS NOT NULL AND [Fence]>(0) OR [ActiveJobID] IS NULL AND [ActivePreparationID] IS NULL AND [ActiveOutputOperationID] IS NOT NULL AND [OwnerID] IS NOT NULL AND [Fence]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Ownership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [CK_ExportResource_Ownership]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Version]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource]  WITH CHECK ADD  CONSTRAINT [CK_ExportResource_Version] CHECK  (([Version]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportResource_Version]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportResource]'))
ALTER TABLE [dbo].[ExportResource] CHECK CONSTRAINT [CK_ExportResource_Version]
