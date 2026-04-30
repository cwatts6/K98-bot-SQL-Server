SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[InventoryImportBatch](
	[ImportBatchID] [bigint] IDENTITY(1,1) NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[DiscordUserID] [bigint] NOT NULL,
	[ImportType] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[FlowType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceMessageID] [bigint] NULL,
	[SourceChannelID] [bigint] NULL,
	[ImageAttachmentURL] [nvarchar](2048) COLLATE Latin1_General_CI_AS NULL,
	[AdminDebugChannelID] [bigint] NULL,
	[AdminDebugMessageID] [bigint] NULL,
	[Status] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedAtUtc] [datetime2](3) NOT NULL,
	[ApprovedAtUtc] [datetime2](3) NULL,
	[RejectedAtUtc] [datetime2](3) NULL,
	[RetryCount] [int] NOT NULL,
	[VisionModel] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[VisionPromptVersion] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[FallbackUsed] [bit] NOT NULL,
	[ConfidenceScore] [decimal](5, 4) NULL,
	[DetectedJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CorrectedJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[FinalJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[WarningJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[ErrorJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[IsAdminImport] [bit] NOT NULL,
	[OriginalUploadDeletedAtUtc] [datetime2](3) NULL,
	[ExpiresAtUtc] [datetime2](3) NULL,
	[ApprovedDateUtc]  AS (CONVERT([date],[ApprovedAtUtc])) PERSISTED,
 CONSTRAINT [PK_InventoryImportBatch] PRIMARY KEY CLUSTERED 
(
	[ImportBatchID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND name = N'IX_InventoryImportBatch_Audit')
CREATE NONCLUSTERED INDEX [IX_InventoryImportBatch_Audit] ON [dbo].[InventoryImportBatch]
(
	[Status] ASC,
	[ImportType] ASC,
	[CreatedAtUtc] ASC
)
INCLUDE([GovernorID],[DiscordUserID],[AdminDebugChannelID],[AdminDebugMessageID],[ConfidenceScore]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND name = N'IX_InventoryImportBatch_DiscordUser_Status')
CREATE NONCLUSTERED INDEX [IX_InventoryImportBatch_DiscordUser_Status] ON [dbo].[InventoryImportBatch]
(
	[DiscordUserID] ASC,
	[Status] ASC,
	[FlowType] ASC,
	[ExpiresAtUtc] ASC
)
INCLUDE([GovernorID],[ImportType],[CreatedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND name = N'IX_InventoryImportBatch_Governor_Status_Expires')
CREATE NONCLUSTERED INDEX [IX_InventoryImportBatch_Governor_Status_Expires] ON [dbo].[InventoryImportBatch]
(
	[GovernorID] ASC,
	[Status] ASC,
	[ExpiresAtUtc] ASC
)
INCLUDE([DiscordUserID],[ImportType],[CreatedAtUtc]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND name = N'UX_InventoryImportBatch_ActiveGovernor')
CREATE UNIQUE NONCLUSTERED INDEX [UX_InventoryImportBatch_ActiveGovernor] ON [dbo].[InventoryImportBatch]
(
	[GovernorID] ASC
)
WHERE ([Status] IN (N'awaiting_upload', N'analysed'))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]') AND name = N'UX_InventoryImportBatch_ApprovedDaily')
CREATE UNIQUE NONCLUSTERED INDEX [UX_InventoryImportBatch_ApprovedDaily] ON [dbo].[InventoryImportBatch]
(
	[GovernorID] ASC,
	[ImportType] ASC,
	[ApprovedDateUtc] ASC
)
WHERE ([Status]=N'approved' AND [ImportType] IS NOT NULL AND [ApprovedAtUtc] IS NOT NULL AND [IsAdminImport]=(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryImportBatch_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryImportBatch] ADD  CONSTRAINT [DF_InventoryImportBatch_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryImportBatch_RetryCount]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryImportBatch] ADD  CONSTRAINT [DF_InventoryImportBatch_RetryCount]  DEFAULT ((0)) FOR [RetryCount]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryImportBatch_FallbackUsed]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryImportBatch] ADD  CONSTRAINT [DF_InventoryImportBatch_FallbackUsed]  DEFAULT ((0)) FOR [FallbackUsed]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_InventoryImportBatch_IsAdminImport]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[InventoryImportBatch] ADD  CONSTRAINT [DF_InventoryImportBatch_IsAdminImport]  DEFAULT ((0)) FOR [IsAdminImport]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_ConfidenceScore]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch]  WITH CHECK ADD  CONSTRAINT [CK_InventoryImportBatch_ConfidenceScore] CHECK  (([ConfidenceScore] IS NULL OR [ConfidenceScore]>=(0) AND [ConfidenceScore]<=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_ConfidenceScore]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch] CHECK CONSTRAINT [CK_InventoryImportBatch_ConfidenceScore]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_FlowType]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch]  WITH CHECK ADD  CONSTRAINT [CK_InventoryImportBatch_FlowType] CHECK  (([FlowType]=N'upload_first' OR [FlowType]=N'command'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_FlowType]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch] CHECK CONSTRAINT [CK_InventoryImportBatch_FlowType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_ImportType]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch]  WITH CHECK ADD  CONSTRAINT [CK_InventoryImportBatch_ImportType] CHECK  (([ImportType] IS NULL OR ([ImportType]=N'unknown' OR [ImportType]=N'materials' OR [ImportType]=N'speedups' OR [ImportType]=N'resources')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_ImportType]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch] CHECK CONSTRAINT [CK_InventoryImportBatch_ImportType]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_RetryCount]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch]  WITH CHECK ADD  CONSTRAINT [CK_InventoryImportBatch_RetryCount] CHECK  (([RetryCount]>=(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_RetryCount]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch] CHECK CONSTRAINT [CK_InventoryImportBatch_RetryCount]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch]  WITH CHECK ADD  CONSTRAINT [CK_InventoryImportBatch_Status] CHECK  (([Status]=N'failed' OR [Status]=N'cancelled' OR [Status]=N'rejected' OR [Status]=N'approved' OR [Status]=N'analysed' OR [Status]=N'awaiting_upload'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_InventoryImportBatch_Status]') AND parent_object_id = OBJECT_ID(N'[dbo].[InventoryImportBatch]'))
ALTER TABLE [dbo].[InventoryImportBatch] CHECK CONSTRAINT [CK_InventoryImportBatch_Status]
