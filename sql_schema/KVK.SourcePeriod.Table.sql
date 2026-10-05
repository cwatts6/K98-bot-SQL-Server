SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourcePeriod]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourcePeriod](
	[PeriodID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PeriodKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[CoverageStartUTC] [datetime2](0) NOT NULL,
	[CoverageEndUTC] [datetime2](0) NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourcePeriod] PRIMARY KEY CLUSTERED 
(
	[PeriodID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePeriod_Identity] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[PeriodKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePeriod_Key] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePeriod_Kind] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodKey] ASC,
	[PeriodKind] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePeriod_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod]  WITH CHECK ADD  CONSTRAINT [CK_SourcePeriod_Kind] CHECK  ((datalength([PeriodKind])=len([PeriodKind]) AND datalength([PeriodKey])=len([PeriodKey]) AND ([PeriodKind]='fight' AND [PeriodKey] like 'fight:%' AND len([PeriodKey])>(6) OR [PeriodKind]='overall' AND [PeriodKey]='overall' OR [PeriodKind]='no_fight' AND [PeriodKey] like 'no_fight:%' AND len([PeriodKey])>(9))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod] CHECK CONSTRAINT [CK_SourcePeriod_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod]  WITH CHECK ADD  CONSTRAINT [CK_SourcePeriod_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod] CHECK CONSTRAINT [CK_SourcePeriod_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod]  WITH CHECK ADD  CONSTRAINT [CK_SourcePeriod_Time] CHECK  (([CoverageEndUTC] IS NULL OR [CoverageEndUTC]>=[CoverageStartUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePeriod_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePeriod]'))
ALTER TABLE [KVK].[SourcePeriod] CHECK CONSTRAINT [CK_SourcePeriod_Time]
