SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_Ingest_Diagnostics](
	[DiagnosticID] [bigint] IDENTITY(1,1) NOT NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[DiagnosticStatus] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[DiagnosticType] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[IngestToken] [uniqueidentifier] NULL,
	[KVK_NO] [int] NULL,
	[ScanID] [int] NULL,
	[SourceFileName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[FileHashSha256] [char](64) COLLATE Latin1_General_CI_AS NULL,
	[UploaderDiscordID] [bigint] NULL,
	[SchemaVersion] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[SourceSheetName] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[SourceColumnHash] [char](64) COLLATE Latin1_General_CI_AS NULL,
	[SourceColumnCount] [int] NULL,
	[SourceRowCount] [int] NULL,
	[StagedRowCount] [int] NULL,
	[ErrorText] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[ContextJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_KVK_Ingest_Diagnostics] PRIMARY KEY CLUSTERED 
(
	[DiagnosticID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]') AND name = N'IX_KVK_IngestDiag_KVK_Scan')
CREATE NONCLUSTERED INDEX [IX_KVK_IngestDiag_KVK_Scan] ON [KVK].[KVK_Ingest_Diagnostics]
(
	[KVK_NO] ASC,
	[ScanID] ASC,
	[CreatedUTC] DESC
)
INCLUDE([DiagnosticStatus],[DiagnosticType],[SourceFileName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]') AND name = N'IX_KVK_IngestDiag_Status_Created')
CREATE NONCLUSTERED INDEX [IX_KVK_IngestDiag_Status_Created] ON [KVK].[KVK_Ingest_Diagnostics]
(
	[DiagnosticStatus] ASC,
	[CreatedUTC] DESC
)
INCLUDE([DiagnosticType],[KVK_NO],[ScanID],[SourceFileName],[SchemaVersion],[SourceSheetName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]') AND name = N'IX_KVK_IngestDiag_Token')
CREATE NONCLUSTERED INDEX [IX_KVK_IngestDiag_Token] ON [KVK].[KVK_Ingest_Diagnostics]
(
	[IngestToken] ASC,
	[CreatedUTC] DESC
)
INCLUDE([DiagnosticStatus],[DiagnosticType],[SourceFileName],[StagedRowCount]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_KVK_IngestDiag_CreatedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Ingest_Diagnostics] ADD  CONSTRAINT [DF_KVK_IngestDiag_CreatedUTC]  DEFAULT (sysutcdatetime()) FOR [CreatedUTC]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_IngestDiag_Status]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]'))
ALTER TABLE [KVK].[KVK_Ingest_Diagnostics]  WITH CHECK ADD  CONSTRAINT [CK_KVK_IngestDiag_Status] CHECK  (([DiagnosticStatus]='cleanup' OR [DiagnosticStatus]='rejected' OR [DiagnosticStatus]='failed'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_IngestDiag_Status]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Diagnostics]'))
ALTER TABLE [KVK].[KVK_Ingest_Diagnostics] CHECK CONSTRAINT [CK_KVK_IngestDiag_Status]
