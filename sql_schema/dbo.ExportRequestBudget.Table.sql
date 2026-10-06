SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportRequestBudget](
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[BudgetKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[NextAllowedUTC] [datetime2](3) NOT NULL,
	[CooldownUntilUTC] [datetime2](3) NULL,
	[IntervalMilliseconds] [int] NOT NULL,
	[PolicyVersion] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
 CONSTRAINT [PK_ExportRequestBudget] PRIMARY KEY CLUSTERED 
(
	[AccountKey] ASC,
	[BudgetKind] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Account]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget]  WITH CHECK ADD  CONSTRAINT [CK_ExportRequestBudget_Account] CHECK  ((len([AccountKey])>(0) AND datalength([AccountKey])=datalength(ltrim(rtrim([AccountKey])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Account]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget] CHECK CONSTRAINT [CK_ExportRequestBudget_Account]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Kind]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget]  WITH CHECK ADD  CONSTRAINT [CK_ExportRequestBudget_Kind] CHECK  (([BudgetKind]='google_request' AND datalength([BudgetKind])=(14)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Kind]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget] CHECK CONSTRAINT [CK_ExportRequestBudget_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Policy]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget]  WITH CHECK ADD  CONSTRAINT [CK_ExportRequestBudget_Policy] CHECK  (([IntervalMilliseconds]>=(1) AND [IntervalMilliseconds]<=(86400000) AND [PolicyVersion]>(0) AND [Version]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportRequestBudget_Policy]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportRequestBudget]'))
ALTER TABLE [dbo].[ExportRequestBudget] CHECK CONSTRAINT [CK_ExportRequestBudget_Policy]
