SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceAggregateReport](
	[ReportID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PeriodKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SelectedRevisionID] [uniqueidentifier] NULL,
	[SelectionVersion] [bigint] NOT NULL,
 CONSTRAINT [PK_SourceAggregateReport] PRIMARY KEY CLUSTERED 
(
	[ReportID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateReport_Kind] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ReportID] ASC,
	[PeriodKind] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateReport_Period] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceAggregateReport_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ReportID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateReport_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport]  WITH CHECK ADD  CONSTRAINT [FK_SourceAggregateReport_Period] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodKey], [PeriodKind])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodKey], [PeriodKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateReport_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport] CHECK CONSTRAINT [FK_SourceAggregateReport_Period]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateReport_SelectedRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport]  WITH CHECK ADD  CONSTRAINT [FK_SourceAggregateReport_SelectedRevision] FOREIGN KEY([SourceKey], [KVK_NO], [ReportID], [SelectedRevisionID])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [ReportID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceAggregateReport_SelectedRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport] CHECK CONSTRAINT [FK_SourceAggregateReport_SelectedRevision]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateReport_Period] CHECK  (([PeriodKind]='fight' AND [PeriodKey] like 'fight:%' AND len([PeriodKey])>(6) OR [PeriodKind]='overall' AND [PeriodKey]='overall' AND datalength([PeriodKey])=(7)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport] CHECK CONSTRAINT [CK_SourceAggregateReport_Period]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateReport_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport] CHECK CONSTRAINT [CK_SourceAggregateReport_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Selection]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport]  WITH CHECK ADD  CONSTRAINT [CK_SourceAggregateReport_Selection] CHECK  (([SelectionVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceAggregateReport_Selection]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceAggregateReport]'))
ALTER TABLE [KVK].[SourceAggregateReport] CHECK CONSTRAINT [CK_SourceAggregateReport_Selection]
