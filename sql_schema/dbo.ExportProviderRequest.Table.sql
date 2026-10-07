SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportProviderRequest](
	[RequestID] [uniqueidentifier] NOT NULL,
	[StreamID] [uniqueidentifier] NOT NULL,
	[Sequence] [bigint] NOT NULL,
	[Operation] [varchar](64) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RequestKind] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[TargetID] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PayloadHash] [binary](32) NOT NULL,
	[PayloadReference] [uniqueidentifier] NOT NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ExportProviderRequest] PRIMARY KEY CLUSTERED 
(
	[RequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportProviderRequest_Sequence] UNIQUE NONCLUSTERED 
(
	[StreamID] ASC,
	[Sequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportProviderRequest_Stream]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest]  WITH CHECK ADD  CONSTRAINT [FK_ExportProviderRequest_Stream] FOREIGN KEY([StreamID])
REFERENCES [dbo].[ExportExecutionStream] ([StreamID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportProviderRequest_Stream]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest] CHECK CONSTRAINT [FK_ExportProviderRequest_Stream]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Operation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest]  WITH CHECK ADD  CONSTRAINT [CK_ExportProviderRequest_Operation] CHECK  ((datalength([Operation])=len([Operation]) AND datalength([RequestKind])=len([RequestKind]) AND ([RequestKind]='read' AND ([Operation]='drive.permissions.list' OR [Operation]='drive.files.get' OR [Operation]='sheets.values.batchGet' OR [Operation]='sheets.values.get' OR [Operation]='sheets.get') OR [RequestKind]='mutation' AND ([Operation]='sheets.create' OR [Operation]='drive.permissions.delete' OR [Operation]='drive.permissions.create' OR [Operation]='drive.files.update' OR [Operation]='sheets.values.clear' OR [Operation]='sheets.values.update' OR [Operation]='sheets.batchUpdate'))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Operation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest] CHECK CONSTRAINT [CK_ExportProviderRequest_Operation]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Sequence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest]  WITH CHECK ADD  CONSTRAINT [CK_ExportProviderRequest_Sequence] CHECK  (([Sequence]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Sequence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest] CHECK CONSTRAINT [CK_ExportProviderRequest_Sequence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Target]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest]  WITH CHECK ADD  CONSTRAINT [CK_ExportProviderRequest_Target] CHECK  ((len([TargetID])>(0) AND datalength([TargetID])=len([TargetID]) AND NOT [TargetID] like ('%[^A-Za-z0-9_-]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequest_Target]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequest]'))
ALTER TABLE [dbo].[ExportProviderRequest] CHECK CONSTRAINT [CK_ExportProviderRequest_Target]
