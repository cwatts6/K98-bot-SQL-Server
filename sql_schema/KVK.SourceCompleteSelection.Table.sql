SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceCompleteSelection](
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[UpdateID] [uniqueidentifier] NOT NULL,
	[PublicationID] [uniqueidentifier] NOT NULL,
	[PublicSelectionVersion] [bigint] NOT NULL,
	[SelectedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceCompleteSelection] PRIMARY KEY CLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCompleteSelection_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection]  WITH CHECK ADD  CONSTRAINT [FK_SourceCompleteSelection_Publication] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCompleteSelection_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection] CHECK CONSTRAINT [FK_SourceCompleteSelection_Publication]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCompleteSelection_Update]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection]  WITH CHECK ADD  CONSTRAINT [FK_SourceCompleteSelection_Update] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [UpdateID])
REFERENCES [KVK].[SourceUpdate] ([SourceKey], [KVK_NO], [PeriodID], [UpdateID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCompleteSelection_Update]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection] CHECK CONSTRAINT [FK_SourceCompleteSelection_Update]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCompleteSelection_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection]  WITH CHECK ADD  CONSTRAINT [CK_SourceCompleteSelection_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCompleteSelection_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection] CHECK CONSTRAINT [CK_SourceCompleteSelection_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCompleteSelection_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection]  WITH CHECK ADD  CONSTRAINT [CK_SourceCompleteSelection_Version] CHECK  (([PublicSelectionVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCompleteSelection_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCompleteSelection]'))
ALTER TABLE [KVK].[SourceCompleteSelection] CHECK CONSTRAINT [CK_SourceCompleteSelection_Version]
