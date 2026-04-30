SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorResourceInventory](
	[ResourceRecordID] [bigint] IDENTITY(1,1) NOT NULL,
	[ImportBatchID] [bigint] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[ScanUtc] [datetime2](3) NOT NULL,
	[ResourceType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[FromItemsValue] [bigint] NOT NULL,
	[TotalResourcesValue] [bigint] NOT NULL,
 CONSTRAINT [PK_GovernorResourceInventory] PRIMARY KEY CLUSTERED 
(
	[ResourceRecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]') AND name = N'IX_GovernorResourceInventory_Governor_ScanUtc')
CREATE NONCLUSTERED INDEX [IX_GovernorResourceInventory_Governor_ScanUtc] ON [dbo].[GovernorResourceInventory]
(
	[GovernorID] ASC,
	[ScanUtc] DESC
)
INCLUDE([ResourceType],[FromItemsValue],[TotalResourcesValue],[ImportBatchID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]') AND name = N'UX_GovernorResourceInventory_Batch_Type')
CREATE UNIQUE NONCLUSTERED INDEX [UX_GovernorResourceInventory_Batch_Type] ON [dbo].[GovernorResourceInventory]
(
	[ImportBatchID] ASC,
	[ResourceType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorResourceInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory]  WITH CHECK ADD  CONSTRAINT [FK_GovernorResourceInventory_ImportBatch] FOREIGN KEY([ImportBatchID])
REFERENCES [dbo].[InventoryImportBatch] ([ImportBatchID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorResourceInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory] CHECK CONSTRAINT [FK_GovernorResourceInventory_ImportBatch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_FromItemsValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorResourceInventory_FromItemsValue] CHECK  (([FromItemsValue]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_FromItemsValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory] CHECK CONSTRAINT [CK_GovernorResourceInventory_FromItemsValue]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_ResourceType]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorResourceInventory_ResourceType] CHECK  (([ResourceType]=N'gold' OR [ResourceType]=N'stone' OR [ResourceType]=N'wood' OR [ResourceType]=N'food'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_ResourceType]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory] CHECK CONSTRAINT [CK_GovernorResourceInventory_ResourceType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_TotalResourcesValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorResourceInventory_TotalResourcesValue] CHECK  (([TotalResourcesValue]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorResourceInventory_TotalResourcesValue]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorResourceInventory]'))
ALTER TABLE [dbo].[GovernorResourceInventory] CHECK CONSTRAINT [CK_GovernorResourceInventory_TotalResourcesValue]
