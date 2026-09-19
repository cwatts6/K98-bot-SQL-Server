SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVKFinalReportHeader](
	[KVK_NO] [int] NOT NULL,
	[FinalDataAtUtc] [datetime2](0) NOT NULL,
	[FinalScanOrder] [int] NOT NULL,
	[OutputRowCount] [int] NOT NULL,
	[Revision] [int] NOT NULL,
	[State] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
	[FinalizationBasis] [nvarchar](24) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_KVKFinalReportHeader] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader]  WITH CHECK ADD  CONSTRAINT [CK_KVKFinalReportHeader_Basis] CHECK  (([FinalizationBasis]=N'INFERRED_BACKFILL' OR [FinalizationBasis]=N'AUDIT_BACKFILL' OR [FinalizationBasis]=N'LIVE_OUTPUT'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_Basis]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader] CHECK CONSTRAINT [CK_KVKFinalReportHeader_Basis]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader]  WITH CHECK ADD  CONSTRAINT [CK_KVKFinalReportHeader_State] CHECK  (([State]=N'OUTPUT_COMPLETE'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader] CHECK CONSTRAINT [CK_KVKFinalReportHeader_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader]  WITH CHECK ADD  CONSTRAINT [CK_KVKFinalReportHeader_Values] CHECK  (([KVK_NO]>(0) AND [FinalScanOrder]>(0) AND [OutputRowCount]>(0) AND [Revision]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVKFinalReportHeader_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVKFinalReportHeader]'))
ALTER TABLE [dbo].[KVKFinalReportHeader] CHECK CONSTRAINT [CK_KVKFinalReportHeader_Values]
