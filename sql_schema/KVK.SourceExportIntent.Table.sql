SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceExportIntent](
	[IntentID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ChoiceID] [uniqueidentifier] NOT NULL,
	[CommitSequence] [bigint] NOT NULL,
	[VectorHash] [binary](32) NOT NULL,
	[ExportSchemaVersion] [varchar](64) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[IntentState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[SupersededByIntentID] [uniqueidentifier] NULL,
 CONSTRAINT [PK_SourceExportIntent] PRIMARY KEY CLUSTERED 
(
	[IntentID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceExportIntent_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[IntentID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceExportIntent_Sequence] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[CommitSequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceExportIntent_Vector] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[VectorHash] ASC,
	[ExportSchemaVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntent_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent]  WITH CHECK ADD  CONSTRAINT [FK_SourceExportIntent_Choice] FOREIGN KEY([KVK_NO], [SourceKey], [ChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntent_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent] CHECK CONSTRAINT [FK_SourceExportIntent_Choice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntent_Superseded]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent]  WITH CHECK ADD  CONSTRAINT [FK_SourceExportIntent_Superseded] FOREIGN KEY([SourceKey], [KVK_NO], [SupersededByIntentID])
REFERENCES [KVK].[SourceExportIntent] ([SourceKey], [KVK_NO], [IntentID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceExportIntent_Superseded]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent] CHECK CONSTRAINT [FK_SourceExportIntent_Superseded]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent]  WITH CHECK ADD  CONSTRAINT [CK_SourceExportIntent_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent] CHECK CONSTRAINT [CK_SourceExportIntent_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent]  WITH CHECK ADD  CONSTRAINT [CK_SourceExportIntent_State] CHECK  ((datalength([IntentState])=len([IntentState]) AND ([IntentState]='blocked' OR [IntentState]='confirmed' OR [IntentState]='coalesced' OR [IntentState]='materialized' OR [IntentState]='waiting_destination' OR [IntentState]='pending') AND ([IntentState]='coalesced' AND [SupersededByIntentID] IS NOT NULL AND [SupersededByIntentID]<>[IntentID] OR [IntentState]<>'coalesced' AND [SupersededByIntentID] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent] CHECK CONSTRAINT [CK_SourceExportIntent_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent]  WITH CHECK ADD  CONSTRAINT [CK_SourceExportIntent_Version] CHECK  (([CommitSequence]>(0) AND len([ExportSchemaVersion])>(0) AND datalength([ExportSchemaVersion])=len([ExportSchemaVersion])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceExportIntent_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceExportIntent]'))
ALTER TABLE [KVK].[SourceExportIntent] CHECK CONSTRAINT [CK_SourceExportIntent_Version]
