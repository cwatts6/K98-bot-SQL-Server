SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVK_Target_Publication](
	[PublicationId] [bigint] IDENTITY(1,1) NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PublicationState] [nvarchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceScanOrder] [int] NOT NULL,
	[SourceScanType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[ConfiguredDraftScan] [int] NULL,
	[ConfiguredMatchmakingScan] [int] NULL,
	[PublishedAtUtc] [datetime2](3) NOT NULL,
	[TargetRowCount] [int] NOT NULL,
	[OutputObjectName] [nvarchar](257) COLLATE Latin1_General_CI_AS NOT NULL,
	[PublicationVersion] [int] NOT NULL,
	[PublicationSignature] [uniqueidentifier] NOT NULL,
	[IsCurrent] [bit] NOT NULL,
	[ForcedRepublish] [bit] NOT NULL,
	[RepublishReason] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[PublishedBy] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_KVK_Target_Publication] PRIMARY KEY CLUSTERED 
(
	[PublicationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KVK_Target_Publication_KVK_Version] UNIQUE NONCLUSTERED 
(
	[KVK_NO] ASC,
	[PublicationVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KVK_Target_Publication_Signature] UNIQUE NONCLUSTERED 
(
	[PublicationSignature] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]') AND name = N'UX_KVK_Target_Publication_Current')
CREATE UNIQUE NONCLUSTERED INDEX [UX_KVK_Target_Publication_Current] ON [dbo].[KVK_Target_Publication]
(
	[KVK_NO] ASC
)
WHERE ([IsCurrent]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_OutputObject]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Target_Publication_OutputObject] CHECK  (([OutputObjectName]=(N'dbo.EXCEL_EXPORT_KVK_TARGETS_'+CONVERT([nvarchar](20),[KVK_NO]))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_OutputObject]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication] CHECK CONSTRAINT [CK_KVK_Target_Publication_OutputObject]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_RepublishAudit]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Target_Publication_RepublishAudit] CHECK  (([ForcedRepublish]=(0) AND [RepublishReason] IS NULL OR [ForcedRepublish]=(1) AND nullif(ltrim(rtrim([RepublishReason])),N'') IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_RepublishAudit]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication] CHECK CONSTRAINT [CK_KVK_Target_Publication_RepublishAudit]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_StateSource]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Target_Publication_StateSource] CHECK  (([PublicationState]=N'DRAFT' AND [SourceScanType]=N'DRAFTSCAN' AND [ConfiguredDraftScan] IS NOT NULL AND [SourceScanOrder]<=[ConfiguredDraftScan] OR [PublicationState]=N'OFFICIAL' AND [SourceScanType]=N'MATCHMAKING_SCAN' AND [ConfiguredMatchmakingScan] IS NOT NULL AND [SourceScanOrder]=[ConfiguredMatchmakingScan]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_StateSource]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication] CHECK CONSTRAINT [CK_KVK_Target_Publication_StateSource]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Target_Publication_Values] CHECK  (([KVK_NO]>(0) AND [SourceScanOrder]>(0) AND [TargetRowCount]>(0) AND [PublicationVersion]>(0) AND ([ConfiguredDraftScan] IS NULL OR [ConfiguredDraftScan]>(0)) AND ([ConfiguredMatchmakingScan] IS NULL OR [ConfiguredMatchmakingScan]>(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication]'))
ALTER TABLE [dbo].[KVK_Target_Publication] CHECK CONSTRAINT [CK_KVK_Target_Publication_Values]
