SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceCampConfig](
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[Kingdom] [int] NOT NULL,
	[CampID] [tinyint] NOT NULL,
	[CampName] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[CampKey] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT [PK_SourceCampConfig] PRIMARY KEY CLUSTERED 
(
	[ConfigVersionID] ASC,
	[Kingdom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceCampConfig_Attribution] UNIQUE NONCLUSTERED 
(
	[ConfigVersionID] ASC,
	[Kingdom] ASC,
	[CampID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]') AND name = N'IX_SourceCampConfig_Camp')
CREATE NONCLUSTERED INDEX [IX_SourceCampConfig_Camp] ON [KVK].[SourceCampConfig]
(
	[ConfigVersionID] ASC,
	[CampID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCampConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig]  WITH CHECK ADD  CONSTRAINT [FK_SourceCampConfig_Config] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCampConfig_Config]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig] CHECK CONSTRAINT [FK_SourceCampConfig_Config]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampConfig_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampConfig_Identity] CHECK  (([Kingdom]>(0) AND ([CampID]>=(1) AND [CampID]<=(8)) AND len([CampName])>(0) AND len([CampKey])>(0) AND datalength([CampKey])=datalength(ltrim(rtrim([CampKey])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampConfig_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig] CHECK CONSTRAINT [CK_SourceCampConfig_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampConfig_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampConfig_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampConfig]'))
ALTER TABLE [KVK].[SourceCampConfig] CHECK CONSTRAINT [CK_SourceCampConfig_Scope]
