SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportExecutionSession](
	[SessionID] [uniqueidentifier] NOT NULL,
	[AuthorityPrincipal] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[HostIdentity] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[BootID] [uniqueidentifier] NOT NULL,
	[ExecutableHash] [binary](32) NOT NULL,
	[ManifestHash] [binary](32) NOT NULL,
	[ProtocolVersion] [int] NOT NULL,
	[State] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Version] [bigint] NOT NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
	[ClosedUTC] [datetime2](3) NULL,
 CONSTRAINT [PK_ExportExecutionSession] PRIMARY KEY CLUSTERED 
(
	[SessionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionSession_Identity] CHECK  ((len([AuthorityPrincipal])>(0) AND len([HostIdentity])>(0) AND datalength([HostIdentity])=len([HostIdentity]) AND NOT [HostIdentity] like ('%[^A-Za-z0-9_.:-]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession] CHECK CONSTRAINT [CK_ExportExecutionSession_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionSession_State] CHECK  ((datalength([State])=len([State]) AND ([State]='open' AND [ClosedUTC] IS NULL OR [State]='closed' AND [ClosedUTC]>=[CreatedUTC])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession] CHECK CONSTRAINT [CK_ExportExecutionSession_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_Version]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionSession_Version] CHECK  (([ProtocolVersion]=(1) AND [Version]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionSession_Version]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionSession]'))
ALTER TABLE [dbo].[ExportExecutionSession] CHECK CONSTRAINT [CK_ExportExecutionSession_Version]
