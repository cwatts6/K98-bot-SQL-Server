SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceAction]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceAction](
	[ActionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[ActionType] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Actor] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ExpectedSelectionVersion] [bigint] NOT NULL,
	[NewSelectionVersion] [bigint] NOT NULL,
	[OldPublicationID] [uniqueidentifier] NULL,
	[NewPublicationID] [uniqueidentifier] NOT NULL,
	[RequestID] [uniqueidentifier] NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ActionUTC] [datetime2](0) NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceAction] PRIMARY KEY CLUSTERED 
(
	[ActionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAction_Version] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[NewSelectionVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_New]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [FK_SourceAction_New] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [NewPublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_New]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [FK_SourceAction_New]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_Old]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [FK_SourceAction_Old] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [OldPublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_Old]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [FK_SourceAction_Old]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_Request]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [FK_SourceAction_Request] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [RequestID])
REFERENCES [KVK].[SourceConfigRequest] ([SourceKey], [KVK_NO], [PeriodID], [RequestID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAction_Request]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [FK_SourceAction_Request]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [CK_SourceAction_Provenance] CHECK  ((len([Actor])>(0) AND len([Reason])>(0) AND isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [CK_SourceAction_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [CK_SourceAction_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [CK_SourceAction_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Type]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [CK_SourceAction_Type] CHECK  ((([ActionType]='configure' OR [ActionType]='rollback' OR [ActionType]='endpoint_update' OR [ActionType]='correct' OR [ActionType]='finalize' OR [ActionType]='publish') AND datalength([ActionType])=len([ActionType]) AND ([ActionType]<>'endpoint_update' OR [RequestID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Type]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [CK_SourceAction_Type]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction]  WITH CHECK ADD  CONSTRAINT [CK_SourceAction_Version] CHECK  (([ExpectedSelectionVersion]>=(0) AND [NewSelectionVersion]>[ExpectedSelectionVersion] AND ([ExpectedSelectionVersion]=(0) AND [OldPublicationID] IS NULL OR [ExpectedSelectionVersion]>(0) AND [OldPublicationID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAction_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAction]'))
ALTER TABLE [KVK].[SourceAction] CHECK CONSTRAINT [CK_SourceAction_Version]
