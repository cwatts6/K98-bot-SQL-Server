SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceUpdate]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceUpdate](
	[UpdateID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChoiceID] [uniqueidentifier] NOT NULL,
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[RosterID] [uniqueidentifier] NOT NULL,
	[StartScanID] [int] NULL,
	[EndScanID] [int] NULL,
	[StartRevisionID] [uniqueidentifier] NULL,
	[EndRevisionID] [uniqueidentifier] NULL,
	[AggregateReportID] [uniqueidentifier] NULL,
	[AggregateRevisionID] [uniqueidentifier] NULL,
	[CoverageStartUTC] [datetime2](0) NOT NULL,
	[CoverageEndUTC] [datetime2](0) NOT NULL,
	[AsOfUTC] [datetime2](0) NOT NULL,
	[UpdateKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[UpdateState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[BaseUpdateID] [uniqueidentifier] NULL,
	[CounterpartRevisionID] [uniqueidentifier] NULL,
	[ConfirmedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ConfirmedUTC] [datetime2](0) NOT NULL,
	[ConfirmationJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[RequestID] [uniqueidentifier] NULL,
	[ContentHash] [binary](32) NOT NULL,
	[Version] [bigint] NOT NULL,
	[PeriodKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT [PK_SourceUpdate] PRIMARY KEY CLUSTERED 
(
	[UpdateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceUpdate_Config] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[UpdateID] ASC,
	[ConfigVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceUpdate_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[UpdateID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Aggregate]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Aggregate] FOREIGN KEY([SourceKey], [KVK_NO], [AggregateReportID], [AggregateRevisionID])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [ReportID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Aggregate]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Aggregate]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_AggregateKind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_AggregateKind] FOREIGN KEY([SourceKey], [KVK_NO], [AggregateReportID], [UpdateKind])
REFERENCES [KVK].[SourceAggregateReport] ([SourceKey], [KVK_NO], [ReportID], [PeriodKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_AggregateKind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_AggregateKind]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Base]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Base] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [BaseUpdateID])
REFERENCES [KVK].[SourceUpdate] ([SourceKey], [KVK_NO], [PeriodID], [UpdateID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Base]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Base]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Choice] FOREIGN KEY([KVK_NO], [SourceKey], [ChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Choice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_ConfigRoster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_ConfigRoster] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID], [RosterID])
REFERENCES [KVK].[SourceConfigVersion] ([SourceKey], [KVK_NO], [ConfigVersionID], [RosterID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_ConfigRoster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_ConfigRoster]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_EndBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_EndBinding] FOREIGN KEY([ConfigVersionID], [EndScanID])
REFERENCES [KVK].[SourceScanBinding] ([ConfigVersionID], [LogicalScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_EndBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_EndBinding]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_EndRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_EndRevision] FOREIGN KEY([SourceKey], [KVK_NO], [EndRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_EndRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_EndRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Kind] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodKey], [PeriodKind])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodKey], [PeriodKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Kind]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Period] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Period]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Request]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Request] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [RequestID])
REFERENCES [KVK].[SourceConfigRequest] ([SourceKey], [KVK_NO], [PeriodID], [RequestID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Request]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Request]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_StartBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_StartBinding] FOREIGN KEY([ConfigVersionID], [StartScanID])
REFERENCES [KVK].[SourceScanBinding] ([ConfigVersionID], [LogicalScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_StartBinding]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_StartBinding]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_StartRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_StartRevision] FOREIGN KEY([SourceKey], [KVK_NO], [StartRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_StartRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_StartRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Window]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [FK_SourceUpdate_Window] FOREIGN KEY([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
REFERENCES [KVK].[SourceWindowConfig] ([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceUpdate_Window]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [FK_SourceUpdate_Window]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Confirmation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_Confirmation] CHECK  ((len([ConfirmedBy])>(0) AND isjson([ConfirmationJson])=(1) AND datalength([ConfirmationJson])<=(65536) AND ([BaseUpdateID] IS NULL OR [BaseUpdateID]<>[UpdateID]) AND ([CounterpartRevisionID] IS NULL OR [BaseUpdateID] IS NOT NULL AND ([StartRevisionID] IS NOT NULL AND [CounterpartRevisionID]=[StartRevisionID] OR [EndRevisionID] IS NOT NULL AND [CounterpartRevisionID]=[EndRevisionID] OR [AggregateRevisionID] IS NOT NULL AND [CounterpartRevisionID]=[AggregateRevisionID]))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Confirmation]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_Confirmation]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Inputs]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_Inputs] CHECK  ((([StartScanID] IS NULL AND [StartRevisionID] IS NULL OR [StartScanID] IS NOT NULL AND [StartRevisionID] IS NOT NULL) AND ([EndScanID] IS NULL AND [EndRevisionID] IS NULL OR [EndScanID] IS NOT NULL AND [EndRevisionID] IS NOT NULL) AND ([AggregateReportID] IS NULL AND [AggregateRevisionID] IS NULL OR [AggregateReportID] IS NOT NULL AND [AggregateRevisionID] IS NOT NULL) AND ([StartScanID] IS NULL OR [EndScanID] IS NULL OR [EndScanID]>=[StartScanID])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Inputs]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_Inputs]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_Kind] CHECK  ((datalength([UpdateKind])=len([UpdateKind]) AND ([UpdateKind]='no_fight' OR [UpdateKind]='overall' OR [UpdateKind]='fight') AND ([UpdateKind]<>'no_fight' OR [AggregateReportID] IS NULL AND [AggregateRevisionID] IS NULL AND ([StartScanID] IS NULL OR [EndScanID] IS NULL OR [StartScanID]=[EndScanID] AND [StartRevisionID]=[EndRevisionID]))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_PeriodMode]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_PeriodMode] CHECK  ((datalength([PeriodKind])=len([PeriodKind]) AND ([PeriodKind]='no_fight' OR [PeriodKind]='overall' OR [PeriodKind]='fight') AND ([UpdateKind]=[PeriodKind] OR [PeriodKind]='fight' AND [UpdateKind]='no_fight')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_PeriodMode]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_PeriodMode]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_State] CHECK  ((datalength([UpdateState])=len([UpdateState]) AND [Version]>(0) AND ([UpdateState]='waiting_player' AND ([StartRevisionID] IS NULL OR [EndRevisionID] IS NULL) OR [UpdateState]='waiting_aggregate' AND [UpdateKind]<>'no_fight' AND [StartRevisionID] IS NOT NULL AND [EndRevisionID] IS NOT NULL AND [AggregateRevisionID] IS NULL OR ([UpdateState]='rejected' OR [UpdateState]='superseded' OR [UpdateState]='selected' OR [UpdateState]='ready') AND [StartRevisionID] IS NOT NULL AND [EndRevisionID] IS NOT NULL AND ([UpdateKind]='no_fight' OR [AggregateRevisionID] IS NOT NULL))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate]  WITH CHECK ADD  CONSTRAINT [CK_SourceUpdate_Time] CHECK  (([CoverageEndUTC]>=[CoverageStartUTC] AND [AsOfUTC]>=[CoverageEndUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceUpdate_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceUpdate]'))
ALTER TABLE [KVK].[SourceUpdate] CHECK CONSTRAINT [CK_SourceUpdate_Time]
