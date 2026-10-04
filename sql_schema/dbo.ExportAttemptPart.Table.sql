SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportAttemptPart](
	[AttemptID] [uniqueidentifier] NOT NULL,
	[PartNo] [int] NOT NULL,
	[PartCount] [int] NOT NULL,
	[FileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Role] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ManifestHash] [binary](32) NOT NULL,
	[GridCount] [int] NOT NULL,
	[RowCount] [bigint] NOT NULL,
	[CellCount] [bigint] NOT NULL,
	[VerificationState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[VerifiedUTC] [datetime2](0) NULL,
	[AclState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AclCheckedUTC] [datetime2](0) NULL,
	[QuarantineState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[QuarantinedUTC] [datetime2](0) NULL,
	[QuarantineReason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
	[EvidenceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[Version] [bigint] NOT NULL,
 CONSTRAINT [PK_ExportAttemptPart] PRIMARY KEY CLUSTERED 
(
	[AttemptID] ASC,
	[PartNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportAttemptPart_File] UNIQUE NONCLUSTERED 
(
	[AttemptID] ASC,
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportAttemptPart_NumberFile] UNIQUE NONCLUSTERED 
(
	[AttemptID] ASC,
	[PartNo] ASC,
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttemptPart_Attempt]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttemptPart_Attempt] FOREIGN KEY([AttemptID], [PartCount])
REFERENCES [dbo].[ExportAttempt] ([AttemptID], [PartCount])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttemptPart_Attempt]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [FK_ExportAttemptPart_Attempt]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Acl]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Acl] CHECK  ((datalength([AclState])=len([AclState]) AND ([AclState]='uncertain' OR [AclState]='failed' OR [AclState]='public_viewer' OR [AclState]='private' OR [AclState]='pending') AND ([AclState]='pending' AND [AclCheckedUTC] IS NULL OR [AclState]<>'pending' AND [AclCheckedUTC] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Acl]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Acl]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Counts]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Counts] CHECK  (([GridCount]>(0) AND [RowCount]>=(0) AND [CellCount]>(0) AND [CellCount]>=[RowCount] AND [Version]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Counts]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Counts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Evidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Evidence] CHECK  (([EvidenceJson] IS NULL OR isjson([EvidenceJson])=(1) AND datalength([EvidenceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Evidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Evidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_File]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_File] CHECK  ((len([FileID])>(0) AND datalength([FileID])=datalength(ltrim(rtrim([FileID])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_File]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_File]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Number]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Number] CHECK  (([PartCount]>=(1) AND [PartCount]<=(1024) AND ([PartNo]>=(1) AND [PartNo]<=[PartCount])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Number]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Number]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Quarantine]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Quarantine] CHECK  ((datalength([QuarantineState])=len([QuarantineState]) AND ([QuarantineState]='quarantined' OR [QuarantineState]='none') AND ([QuarantineState]='none' AND [QuarantinedUTC] IS NULL AND [QuarantineReason] IS NULL OR [QuarantineState]='quarantined' AND [QuarantinedUTC] IS NOT NULL AND [QuarantineReason] IS NOT NULL AND len([QuarantineReason])>(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Quarantine]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Quarantine]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Role]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Role] CHECK  ((datalength([Role])=len([Role]) AND ([Role]='output' OR [Role]='generation' OR [Role]='index')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Role]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Role]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttemptPart_Verification] CHECK  ((datalength([VerificationState])=len([VerificationState]) AND ([VerificationState]='uncertain' OR [VerificationState]='failed' OR [VerificationState]='verified' OR [VerificationState]='pending') AND ([VerificationState]='verified' AND [VerifiedUTC] IS NOT NULL OR [VerificationState]<>'verified' AND [VerifiedUTC] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttemptPart_Verification]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttemptPart]'))
ALTER TABLE [dbo].[ExportAttemptPart] CHECK CONSTRAINT [CK_ExportAttemptPart_Verification]
