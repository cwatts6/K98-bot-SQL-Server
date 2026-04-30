SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorSpeedupInventory](
	[SpeedupRecordID] [bigint] IDENTITY(1,1) NOT NULL,
	[ImportBatchID] [bigint] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[ScanUtc] [datetime2](3) NOT NULL,
	[SpeedupType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[TotalMinutes] [bigint] NOT NULL,
	[TotalHours] [decimal](18, 4) NOT NULL,
	[TotalDaysDecimal] [decimal](18, 4) NOT NULL,
 CONSTRAINT [PK_GovernorSpeedupInventory] PRIMARY KEY CLUSTERED 
(
	[SpeedupRecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]') AND name = N'IX_GovernorSpeedupInventory_Governor_ScanUtc')
CREATE NONCLUSTERED INDEX [IX_GovernorSpeedupInventory_Governor_ScanUtc] ON [dbo].[GovernorSpeedupInventory]
(
	[GovernorID] ASC,
	[ScanUtc] DESC
)
INCLUDE([SpeedupType],[TotalMinutes],[TotalHours],[TotalDaysDecimal],[ImportBatchID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]') AND name = N'UX_GovernorSpeedupInventory_Batch_Type')
CREATE UNIQUE NONCLUSTERED INDEX [UX_GovernorSpeedupInventory_Batch_Type] ON [dbo].[GovernorSpeedupInventory]
(
	[ImportBatchID] ASC,
	[SpeedupType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorSpeedupInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory]  WITH CHECK ADD  CONSTRAINT [FK_GovernorSpeedupInventory_ImportBatch] FOREIGN KEY([ImportBatchID])
REFERENCES [dbo].[InventoryImportBatch] ([ImportBatchID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_GovernorSpeedupInventory_ImportBatch]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory] CHECK CONSTRAINT [FK_GovernorSpeedupInventory_ImportBatch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_SpeedupType]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorSpeedupInventory_SpeedupType] CHECK  (([SpeedupType]=N'universal' OR [SpeedupType]=N'healing' OR [SpeedupType]=N'training' OR [SpeedupType]=N'research' OR [SpeedupType]=N'building'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_SpeedupType]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory] CHECK CONSTRAINT [CK_GovernorSpeedupInventory_SpeedupType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalDaysDecimal]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorSpeedupInventory_TotalDaysDecimal] CHECK  (([TotalDaysDecimal]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalDaysDecimal]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory] CHECK CONSTRAINT [CK_GovernorSpeedupInventory_TotalDaysDecimal]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalHours]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorSpeedupInventory_TotalHours] CHECK  (([TotalHours]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalHours]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory] CHECK CONSTRAINT [CK_GovernorSpeedupInventory_TotalHours]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalMinutes]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory]  WITH CHECK ADD  CONSTRAINT [CK_GovernorSpeedupInventory_TotalMinutes] CHECK  (([TotalMinutes]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_GovernorSpeedupInventory_TotalMinutes]') AND parent_object_id = OBJECT_ID(N'[dbo].[GovernorSpeedupInventory]'))
ALTER TABLE [dbo].[GovernorSpeedupInventory] CHECK CONSTRAINT [CK_GovernorSpeedupInventory_TotalMinutes]
