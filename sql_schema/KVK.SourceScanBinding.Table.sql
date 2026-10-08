SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceScanBinding](
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[LogicalScanID] [int] NOT NULL,
 CONSTRAINT [PK_SourceScanBinding] PRIMARY KEY CLUSTERED 
(
	[ConfigVersionID] ASC,
	[LogicalScanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceScanBinding_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding]  WITH CHECK ADD  CONSTRAINT [FK_SourceScanBinding_Config] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceScanBinding_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding] CHECK CONSTRAINT [FK_SourceScanBinding_Config]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceScanBinding_Scan]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding]  WITH CHECK ADD  CONSTRAINT [FK_SourceScanBinding_Scan] FOREIGN KEY([SourceKey], [KVK_NO], [LogicalScanID])
REFERENCES [KVK].[SourceLogicalScan] ([SourceKey], [KVK_NO], [LogicalScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceScanBinding_Scan]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding] CHECK CONSTRAINT [FK_SourceScanBinding_Scan]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceScanBinding_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding]  WITH CHECK ADD  CONSTRAINT [CK_SourceScanBinding_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceScanBinding_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceScanBinding]'))
ALTER TABLE [KVK].[SourceScanBinding] CHECK CONSTRAINT [CK_SourceScanBinding_Scope]
