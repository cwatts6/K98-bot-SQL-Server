SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourcePublication]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourcePublication](
	[PublicationID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Generation] [bigint] NOT NULL,
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[RosterID] [uniqueidentifier] NOT NULL,
	[CalculationVersion] [varchar](64) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[StartScanID] [int] NULL,
	[EndScanID] [int] NULL,
	[StartRevisionID] [uniqueidentifier] NULL,
	[EndRevisionID] [uniqueidentifier] NULL,
	[AggregateReportID] [uniqueidentifier] NULL,
	[AggregateRevisionID] [uniqueidentifier] NULL,
	[PlayerState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AggregateState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PeriodState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[BuildState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[EligibleCount] [int] NOT NULL,
	[ResultCount] [int] NOT NULL,
	[KingdomCount] [int] NOT NULL,
	[CampCount] [int] NOT NULL,
	[ManifestHash] [binary](32) NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[CompletedUTC] [datetime2](0) NULL,
	[FinalUnavailableReason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_SourcePublication] PRIMARY KEY CLUSTERED 
(
	[PublicationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePublication_Config] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[ConfigVersionID] ASC,
	[PublicationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePublication_Generation] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[Generation] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePublication_Result] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PublicationID] ASC,
	[ConfigVersionID] ASC,
	[RosterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourcePublication_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[PublicationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Aggregate]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_Aggregate] FOREIGN KEY([SourceKey], [KVK_NO], [AggregateReportID], [AggregateRevisionID])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [ReportID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Aggregate]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_Aggregate]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_ConfigRoster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_ConfigRoster] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID], [RosterID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID], [RosterID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_ConfigRoster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_ConfigRoster]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_EndBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_EndBinding] FOREIGN KEY([ConfigVersionID], [EndScanID])
REFERENCES [KVK].[SourceScanBinding] ([ConfigVersionID], [LogicalScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_EndBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_EndBinding]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_EndRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_EndRevision] FOREIGN KEY([SourceKey], [KVK_NO], [EndRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_EndRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_EndRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_Period] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_Period]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_StartBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_StartBinding] FOREIGN KEY([ConfigVersionID], [StartScanID])
REFERENCES [KVK].[SourceScanBinding] ([ConfigVersionID], [LogicalScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_StartBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_StartBinding]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_StartRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_StartRevision] FOREIGN KEY([SourceKey], [KVK_NO], [StartRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_StartRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_StartRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Window]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [FK_SourcePublication_Window] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
REFERENCES [KVK].[SourceWindowConfig] ([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourcePublication_Window]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [FK_SourcePublication_Window]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_AggregateState]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_AggregateState] CHECK  ((datalength([AggregateState])=len([AggregateState]) AND (([AggregateState]='corrected_final' OR [AggregateState]='final' OR [AggregateState]='live') AND [AggregateRevisionID] IS NOT NULL OR ([AggregateState]='final_unavailable' OR [AggregateState]='not_applicable' OR [AggregateState]='validation_failed' OR [AggregateState]='not_received') AND [AggregateRevisionID] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_AggregateState]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_AggregateState]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Build]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Build] CHECK  ((datalength([BuildState])=len([BuildState]) AND ([BuildState]='building' AND [CompletedUTC] IS NULL OR [BuildState]='complete' AND [CompletedUTC] IS NOT NULL AND [ManifestHash] IS NOT NULL AND [ResultCount]=[EligibleCount]) AND ([CompletedUTC] IS NULL OR [CompletedUTC]>=[CreatedUTC])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Build]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Build]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Counts]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Counts] CHECK  (([Generation]>(0) AND ([EligibleCount]>=(1) AND [EligibleCount]<=(50000)) AND ([ResultCount]>=(0) AND [ResultCount]<=[EligibleCount]) AND ([KingdomCount]>=(0) AND [KingdomCount]<=(512)) AND ([CampCount]>=(0) AND [CampCount]<=(8)) AND len([CalculationVersion])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Counts]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Counts]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Final]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Final] CHECK  ((datalength([PeriodState])=len([PeriodState]) AND ([PeriodState]='corrected_final' OR [PeriodState]='final' OR [PeriodState]='live') AND ([PlayerState]<>'final_unavailable' AND [AggregateState]<>'final_unavailable' OR [FinalUnavailableReason] IS NOT NULL AND len([FinalUnavailableReason])>(0)) AND ([PeriodState]='live' OR ([PlayerState]='final_unavailable' OR [PlayerState]='not_applicable' OR [PlayerState]='corrected_final' OR [PlayerState]='final') AND ([AggregateState]='final_unavailable' OR [AggregateState]='not_applicable' OR [AggregateState]='corrected_final' OR [AggregateState]='final'))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Final]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Final]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Inputs]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Inputs] CHECK  ((([StartScanID] IS NULL AND [StartRevisionID] IS NULL OR [StartScanID] IS NOT NULL AND [StartRevisionID] IS NOT NULL) AND ([EndScanID] IS NULL AND [EndRevisionID] IS NULL OR [EndScanID] IS NOT NULL AND [EndRevisionID] IS NOT NULL) AND ([AggregateReportID] IS NULL AND [AggregateRevisionID] IS NULL OR [AggregateReportID] IS NOT NULL AND [AggregateRevisionID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Inputs]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Inputs]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Player]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Player] CHECK  ((datalength([PlayerState])=len([PlayerState]) AND (([PlayerState]='not_applicable' OR [PlayerState]='corrected_final' OR [PlayerState]='final' OR [PlayerState]='live') AND [StartRevisionID] IS NOT NULL AND [EndRevisionID] IS NOT NULL OR ([PlayerState]='final_unavailable' OR [PlayerState]='not_received' OR [PlayerState]='validation_failed' OR [PlayerState]='missing_configuration' OR [PlayerState]='missing_end' OR [PlayerState]='missing_start'))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Player]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Player]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication]  WITH CHECK ADD  CONSTRAINT [CK_SourcePublication_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourcePublication_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourcePublication]'))
ALTER TABLE [KVK].[SourcePublication] CHECK CONSTRAINT [CK_SourcePublication_Scope]
