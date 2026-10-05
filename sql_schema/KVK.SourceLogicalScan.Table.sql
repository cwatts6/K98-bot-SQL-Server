SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceLogicalScan](
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[LogicalScanID] [int] NOT NULL,
	[ObservationID] [uniqueidentifier] NOT NULL,
	[AllocatedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceLogicalScan] PRIMARY KEY CLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[LogicalScanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceLogicalScan_Observation] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceLogicalScan_Observation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan]  WITH CHECK ADD  CONSTRAINT [FK_SourceLogicalScan_Observation] FOREIGN KEY([SourceKey], [KVK_NO], [ObservationID])
REFERENCES [KVK].[SourceObservation] ([SourceKey], [KVK_NO], [ObservationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceLogicalScan_Observation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan] CHECK CONSTRAINT [FK_SourceLogicalScan_Observation]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceLogicalScan_ID]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan]  WITH CHECK ADD  CONSTRAINT [CK_SourceLogicalScan_ID] CHECK  (([LogicalScanID]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceLogicalScan_ID]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan] CHECK CONSTRAINT [CK_SourceLogicalScan_ID]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceLogicalScan_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan]  WITH CHECK ADD  CONSTRAINT [CK_SourceLogicalScan_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceLogicalScan_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceLogicalScan]'))
ALTER TABLE [KVK].[SourceLogicalScan] CHECK CONSTRAINT [CK_SourceLogicalScan_Scope]
