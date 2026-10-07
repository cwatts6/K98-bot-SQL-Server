SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceWindowConfig](
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[WindowName] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[WindowSeq] [tinyint] NULL,
	[StartScanID] [int] NULL,
	[EndScanID] [int] NULL,
	[Notes] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[UpdatedAtUTC] [datetime2](0) NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT [PK_SourceWindowConfig] PRIMARY KEY CLUSTERED 
(
	[ConfigVersionID] ASC,
	[WindowName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceWindowConfig_Period] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ConfigVersionID] ASC,
	[PeriodKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWindowConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig]  WITH CHECK ADD  CONSTRAINT [FK_SourceWindowConfig_Config] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWindowConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig] CHECK CONSTRAINT [FK_SourceWindowConfig_Config]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWindowConfig_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig]  WITH CHECK ADD  CONSTRAINT [FK_SourceWindowConfig_Period] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodKey])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceWindowConfig_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig] CHECK CONSTRAINT [FK_SourceWindowConfig_Period]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Bounds]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceWindowConfig_Bounds] CHECK  ((([StartScanID] IS NULL OR [StartScanID]>(0)) AND ([EndScanID] IS NULL OR [EndScanID]>(0)) AND ([EndScanID] IS NULL OR [StartScanID] IS NULL OR [EndScanID]>=[StartScanID])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Bounds]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig] CHECK CONSTRAINT [CK_SourceWindowConfig_Bounds]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Name]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceWindowConfig_Name] CHECK  ((len([WindowName])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Name]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig] CHECK CONSTRAINT [CK_SourceWindowConfig_Name]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceWindowConfig_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceWindowConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceWindowConfig]'))
ALTER TABLE [KVK].[SourceWindowConfig] CHECK CONSTRAINT [CK_SourceWindowConfig_Scope]
