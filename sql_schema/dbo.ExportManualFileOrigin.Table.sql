SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportManualFileOrigin](
	[FileID] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Stage] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ParentStage] [varchar](16) COLLATE Latin1_General_100_BIN2 NULL,
	[PreparationID] [uniqueidentifier] NOT NULL,
	[Ordinal] [int] NOT NULL,
	[SessionID] [uniqueidentifier] NOT NULL,
	[PlanHash] [binary](32) NOT NULL,
	[ProfileHash] [binary](32) NOT NULL,
	[VerificationStreamID] [uniqueidentifier] NULL,
	[VerificationClosureHash] [binary](32) NULL,
	[EligibilityHash] [binary](32) NULL,
	[EligibilityReference] [uniqueidentifier] NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ExportManualFileOrigin] PRIMARY KEY CLUSTERED 
(
	[FileID] ASC,
	[Stage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportManualFileOrigin_Ordinal] UNIQUE NONCLUSTERED 
(
	[PreparationID] ASC,
	[Ordinal] ASC,
	[Stage] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]') AND name = N'IX_ExportManualFileOrigin_Preparation')
CREATE NONCLUSTERED INDEX [IX_ExportManualFileOrigin_Preparation] ON [dbo].[ExportManualFileOrigin]
(
	[PreparationID] ASC,
	[Stage] ASC,
	[Ordinal] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Parent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManualFileOrigin_Parent] FOREIGN KEY([FileID], [ParentStage])
REFERENCES [dbo].[ExportManualFileOrigin] ([FileID], [Stage])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Parent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [FK_ExportManualFileOrigin_Parent]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManualFileOrigin_Preparation] FOREIGN KEY([PreparationID])
REFERENCES [dbo].[ExportPreparation] ([PreparationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [FK_ExportManualFileOrigin_Preparation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Session]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManualFileOrigin_Session] FOREIGN KEY([SessionID])
REFERENCES [dbo].[ExportExecutionSession] ([SessionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Session]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [FK_ExportManualFileOrigin_Session]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [FK_ExportManualFileOrigin_Verification] FOREIGN KEY([VerificationStreamID], [SessionID])
REFERENCES [dbo].[ExportExecutionStream] ([StreamID], [SessionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportManualFileOrigin_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [FK_ExportManualFileOrigin_Verification]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManualFileOrigin_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [CK_ExportManualFileOrigin_Identity] CHECK  ((datalength([FileID])>=(3) AND datalength([FileID])<=(128) AND datalength([FileID])=len([FileID]) AND NOT [FileID] like ('%[^-A-Za-z0-9_]%') collate Latin1_General_100_BIN2 AND ([Ordinal]>=(0) AND [Ordinal]<=(16))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManualFileOrigin_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [CK_ExportManualFileOrigin_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManualFileOrigin_Stage]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin]  WITH CHECK ADD  CONSTRAINT [CK_ExportManualFileOrigin_Stage] CHECK  ((datalength([Stage])=len([Stage]) AND ([Stage]='registered' AND [ParentStage] IS NULL AND [VerificationStreamID] IS NULL AND [VerificationClosureHash] IS NULL AND [EligibilityHash] IS NULL AND [EligibilityReference] IS NULL OR [Stage]='eligible' AND [ParentStage] IS NOT NULL AND [ParentStage]='registered' AND datalength([ParentStage])=(10) AND [VerificationStreamID] IS NOT NULL AND [VerificationClosureHash] IS NOT NULL AND [EligibilityHash] IS NOT NULL AND [EligibilityReference] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportManualFileOrigin_Stage]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportManualFileOrigin]'))
ALTER TABLE [dbo].[ExportManualFileOrigin] CHECK CONSTRAINT [CK_ExportManualFileOrigin_Stage]
