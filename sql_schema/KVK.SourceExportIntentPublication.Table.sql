SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceExportIntentPublication](
	[IntentID] [uniqueidentifier] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[UpdateID] [uniqueidentifier] NOT NULL,
	[PublicationID] [uniqueidentifier] NOT NULL,
	[PublicSelectionVersion] [bigint] NOT NULL,
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
 CONSTRAINT [PK_SourceExportIntentPublication] PRIMARY KEY CLUSTERED 
(
	[IntentID] ASC,
	[PeriodID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Intent]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication]  WITH CHECK ADD  CONSTRAINT [FK_SourceExportIntentPublication_Intent] FOREIGN KEY([SourceKey], [KVK_NO], [IntentID])
REFERENCES [KVK].[SourceExportIntent] ([SourceKey], [KVK_NO], [IntentID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Intent]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication] CHECK CONSTRAINT [FK_SourceExportIntentPublication_Intent]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication]  WITH CHECK ADD  CONSTRAINT [FK_SourceExportIntentPublication_Publication] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [ConfigVersionID], [PublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [ConfigVersionID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication] CHECK CONSTRAINT [FK_SourceExportIntentPublication_Publication]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Update]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication]  WITH CHECK ADD  CONSTRAINT [FK_SourceExportIntentPublication_Update] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [UpdateID], [ConfigVersionID])
REFERENCES [KVK].[SourceUpdate] ([SourceKey], [KVK_NO], [PeriodID], [UpdateID], [ConfigVersionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntentPublication_Update]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication] CHECK CONSTRAINT [FK_SourceExportIntentPublication_Update]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntentPublication_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication]  WITH CHECK ADD  CONSTRAINT [CK_SourceExportIntentPublication_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntentPublication_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication] CHECK CONSTRAINT [CK_SourceExportIntentPublication_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntentPublication_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication]  WITH CHECK ADD  CONSTRAINT [CK_SourceExportIntentPublication_Version] CHECK  (([PublicSelectionVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntentPublication_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntentPublication]'))
ALTER TABLE [KVK].[SourceExportIntentPublication] CHECK CONSTRAINT [CK_SourceExportIntentPublication_Version]
