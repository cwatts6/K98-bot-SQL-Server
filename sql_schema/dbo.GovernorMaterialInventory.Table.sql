SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorMaterialInventory](
	[MaterialRecordID] [bigint] IDENTITY(1,1) NOT NULL,
	[ImportBatchID] [bigint] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[ScanUtc] [datetime2](3) NOT NULL,
	[MaterialKind] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[Rarity] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[Quantity] [bigint] NOT NULL,
	[LegendaryEquivalent] [decimal](18, 4) NOT NULL,
	[SourceImageIndex] [int] NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_GovernorMaterialInventory] PRIMARY KEY CLUSTERED 
(
	[MaterialRecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]') AND name = N'IX_GovernorMaterialInventory_Governor_Kind_Rarity_ScanUtc')
CREATE NONCLUSTERED INDEX [IX_GovernorMaterialInventory_Governor_Kind_Rarity_ScanUtc] ON [dbo].[GovernorMaterialInventory]
(
	[GovernorID] ASC,
	[MaterialKind] ASC,
	[Rarity] ASC,
	[ScanUtc] DESC
)
INCLUDE([ImportBatchID],[Quantity],[LegendaryEquivalent]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]') AND name = N'IX_GovernorMaterialInventory_Governor_ScanUtc')
CREATE NONCLUSTERED INDEX [IX_GovernorMaterialInventory_Governor_ScanUtc] ON [dbo].[GovernorMaterialInventory]
(
	[GovernorID] ASC,
	[ScanUtc] DESC
)
INCLUDE([ImportBatchID],[MaterialKind],[Rarity],[Quantity],[LegendaryEquivalent]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]') AND name = N'UX_GovernorMaterialInventory_Batch_Kind_Rarity')
CREATE UNIQUE NONCLUSTERED INDEX [UX_GovernorMaterialInventory_Batch_Kind_Rarity] ON [dbo].[GovernorMaterialInventory]
(
	[ImportBatchID] ASC,
	[MaterialKind] ASC,
	[Rarity] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_GovernorMaterialInventory_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[GovernorMaterialInventory] ADD  CONSTRAINT [DF_GovernorMaterialInventory_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorMaterialInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [FK_GovernorMaterialInventory_ImportBatch] FOREIGN KEY([ImportBatchID])
REFERENCES [dbo].[InventoryImportBatch] ([ImportBatchID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorMaterialInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [FK_GovernorMaterialInventory_ImportBatch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_LegendaryEquivalent]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorMaterialInventory_LegendaryEquivalent] CHECK  (([LegendaryEquivalent]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_LegendaryEquivalent]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [CK_GovernorMaterialInventory_LegendaryEquivalent]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_MaterialKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorMaterialInventory_MaterialKind] CHECK  (([MaterialKind]=N'iron_ore' OR [MaterialKind]=N'ebony' OR [MaterialKind]=N'leather' OR [MaterialKind]=N'animal_bone' OR [MaterialKind]=N'choice_chests'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_MaterialKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [CK_GovernorMaterialInventory_MaterialKind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_Quantity]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorMaterialInventory_Quantity] CHECK  (([Quantity]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_Quantity]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [CK_GovernorMaterialInventory_Quantity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_Rarity]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorMaterialInventory_Rarity] CHECK  (([Rarity]=N'legendary' OR [Rarity]=N'epic' OR [Rarity]=N'elite' OR [Rarity]=N'advanced' OR [Rarity]=N'normal'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_Rarity]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [CK_GovernorMaterialInventory_Rarity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_SourceImageIndex]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorMaterialInventory_SourceImageIndex] CHECK  (([SourceImageIndex] IS NULL OR [SourceImageIndex]>=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorMaterialInventory_SourceImageIndex]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorMaterialInventory]'))
ALTER TABLE [dbo].[GovernorMaterialInventory] CHECK CONSTRAINT [CK_GovernorMaterialInventory_SourceImageIndex]
