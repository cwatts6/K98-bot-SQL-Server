SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceSelection]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceSelection](
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[PublicationID] [uniqueidentifier] NOT NULL,
	[SelectionVersion] [bigint] NOT NULL,
	[SelectedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceSelection] PRIMARY KEY CLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceSelection_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection]  WITH CHECK ADD  CONSTRAINT [FK_SourceSelection_Publication] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceSelection_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection] CHECK CONSTRAINT [FK_SourceSelection_Publication]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceSelection_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection]  WITH CHECK ADD  CONSTRAINT [CK_SourceSelection_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceSelection_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection] CHECK CONSTRAINT [CK_SourceSelection_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceSelection_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection]  WITH CHECK ADD  CONSTRAINT [CK_SourceSelection_Version] CHECK  (([SelectionVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceSelection_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceSelection]'))
ALTER TABLE [KVK].[SourceSelection] CHECK CONSTRAINT [CK_SourceSelection_Version]
