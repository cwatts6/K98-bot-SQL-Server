SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportManagedFileOrigin](
	[FileID] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Stage] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ParentStage] [varchar](16) COLLATE Latin1_General_100_BIN2 NULL,
	[PreparationID] [uniqueidentifier] NOT NULL,
	[Ordinal] [int] NOT NULL,
	[SessionID] [uniqueidentifier] NOT NULL,
	[CreationStreamID] [uniqueidentifier] NOT NULL,
	[CreationRequestID] [uniqueidentifier] NOT NULL,
	[ResponseEventID] [uniqueidentifier] NOT NULL,
	[PlanHash] [binary](32) NOT NULL,
	[ProfileHash] [binary](32) NOT NULL,
	[ResponseHash] [binary](32) NOT NULL,
	[CreationClosureHash] [binary](32) NOT NULL,
	[OriginHash] [binary](32) NOT NULL,
	[OriginReference] [uniqueidentifier] NOT NULL,
	[VerificationStreamID] [uniqueidentifier] NULL,
	[VerificationClosureHash] [binary](32) NULL,
	[EligibilityHash] [binary](32) NULL,
	[EligibilityReference] [uniqueidentifier] NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ExportManagedFileOrigin] PRIMARY KEY CLUSTERED 
(
	[FileID] ASC,
	[Stage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportManagedFileOrigin_Ordinal] UNIQUE NONCLUSTERED 
(
	[PreparationID] ASC,
	[Ordinal] ASC,
	[Stage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportManagedFileOrigin_Request] UNIQUE NONCLUSTERED 
(
	[CreationRequestID] ASC,
	[Stage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]') AND name = N'IX_ExportManagedFileOrigin_Preparation')
CREATE NONCLUSTERED INDEX [IX_ExportManagedFileOrigin_Preparation] ON [dbo].[ExportManagedFileOrigin]
(
	[PreparationID] ASC,
	[Stage] ASC,
	[Ordinal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Creation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Creation] FOREIGN KEY([CreationStreamID], [SessionID])
REFERENCES [dbo].[ExportExecutionStream] ([StreamID], [SessionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Creation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Creation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Parent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Parent] FOREIGN KEY([FileID], [ParentStage])
REFERENCES [dbo].[ExportManagedFileOrigin] ([FileID], [Stage])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Parent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Parent]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Preparation] FOREIGN KEY([PreparationID])
REFERENCES [dbo].[ExportPreparation] ([PreparationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Preparation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Request] FOREIGN KEY([CreationRequestID])
REFERENCES [dbo].[ExportProviderRequest] ([RequestID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Request]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Response] FOREIGN KEY([ResponseEventID])
REFERENCES [dbo].[ExportProviderRequestEvent] ([EventID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Response]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Response]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManagedFileOrigin_Verification] FOREIGN KEY([VerificationStreamID], [SessionID])
REFERENCES [dbo].[ExportExecutionStream] ([StreamID], [SessionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManagedFileOrigin_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [FK_ExportManagedFileOrigin_Verification]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManagedFileOrigin_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [CK_ExportManagedFileOrigin_Identity] CHECK  ((datalength([FileID])>=(3) AND datalength([FileID])<=(128) AND datalength([FileID])=len([FileID]) AND NOT [FileID] like ('%[^A-Za-z0-9_-]%') collate Latin1_General_100_BIN2 AND ([Ordinal]>=(0) AND [Ordinal]<=(16))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManagedFileOrigin_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [CK_ExportManagedFileOrigin_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManagedFileOrigin_Stage]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin]  WITH CHECK ADD  CONSTRAINT [CK_ExportManagedFileOrigin_Stage] CHECK  ((datalength([Stage])=len([Stage]) AND ([Stage]='created' AND [ParentStage] IS NULL AND [VerificationStreamID] IS NULL AND [VerificationClosureHash] IS NULL AND [EligibilityHash] IS NULL AND [EligibilityReference] IS NULL OR [Stage]='eligible' AND [ParentStage] IS NOT NULL AND [ParentStage]='created' AND datalength([ParentStage])=(7) AND [VerificationStreamID] IS NOT NULL AND [VerificationClosureHash] IS NOT NULL AND [EligibilityHash] IS NOT NULL AND [EligibilityReference] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManagedFileOrigin_Stage]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManagedFileOrigin]'))
ALTER TABLE [dbo].[ExportManagedFileOrigin] CHECK CONSTRAINT [CK_ExportManagedFileOrigin_Stage]
