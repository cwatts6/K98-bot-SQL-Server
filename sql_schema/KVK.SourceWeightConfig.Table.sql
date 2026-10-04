SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceWeightConfig](
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[WeightT4X] [decimal](38, 12) NOT NULL,
	[WeightT5Y] [decimal](38, 12) NOT NULL,
	[WeightDeadsZ] [decimal](38, 12) NOT NULL,
	[WeightT4XSource] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[WeightT5YSource] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[WeightDeadsZSource] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[EffectiveFromUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceWeightConfig] PRIMARY KEY CLUSTERED 
(
	[ConfigVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWeightConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig]  WITH CHECK ADD  CONSTRAINT [FK_SourceWeightConfig_Config] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWeightConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig] CHECK CONSTRAINT [FK_SourceWeightConfig_Config]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWeightConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceWeightConfig_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWeightConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig] CHECK CONSTRAINT [CK_SourceWeightConfig_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWeightConfig_Strings]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceWeightConfig_Strings] CHECK  ((len([WeightT4XSource])>(0) AND len([WeightT5YSource])>(0) AND len([WeightDeadsZSource])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWeightConfig_Strings]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWeightConfig]'))
ALTER TABLE [KVK].[SourceWeightConfig] CHECK CONSTRAINT [CK_SourceWeightConfig_Strings]
