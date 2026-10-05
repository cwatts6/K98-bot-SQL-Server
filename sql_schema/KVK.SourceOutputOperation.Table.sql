SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputOperation](
	[OperationID] [uniqueidentifier] NOT NULL,
	[PoolID] [uniqueidentifier] NOT NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OldKVK] [int] NOT NULL,
	[OldChoiceID] [uniqueidentifier] NOT NULL,
	[NewKVK] [int] NOT NULL,
	[NewChoiceID] [uniqueidentifier] NOT NULL,
	[OldEpoch] [bigint] NOT NULL,
	[TargetEpoch] [bigint] NOT NULL,
	[PlanHash] [binary](32) NOT NULL,
	[PlanJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[ConfirmedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[GuildID] [varchar](20) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChannelID] [varchar](20) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ConfirmedUTC] [datetime2](0) NOT NULL,
	[EnqueueSequence] [bigint] NOT NULL,
	[State] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActivePoolID] [uniqueidentifier] NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[Phase] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[CurrentFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[ProgressJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceOutputOperation] PRIMARY KEY CLUSTERED 
(
	[OperationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputOperation_Scope] UNIQUE NONCLUSTERED 
(
	[OperationID] ASC,
	[PoolID] ASC,
	[AccountKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]') AND name = N'IX_SourceOutputOperation_Queue')
CREATE NONCLUSTERED INDEX [IX_SourceOutputOperation_Queue] ON [KVK].[SourceOutputOperation]
(
	[AccountKey] ASC,
	[State] ASC,
	[EnqueueSequence] ASC,
	[OperationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]') AND name = N'UX_SourceOutputOperation_ActivePool')
CREATE UNIQUE NONCLUSTERED INDEX [UX_SourceOutputOperation_ActivePool] ON [KVK].[SourceOutputOperation]
(
	[ActivePoolID] ASC
)
WHERE ([ActivePoolID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_CurrentFile]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperation_CurrentFile] FOREIGN KEY([OperationID], [CurrentFileID])
REFERENCES [KVK].[SourceOutputOperationResource] ([OperationID], [FileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_CurrentFile]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [FK_SourceOutputOperation_CurrentFile]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_NewChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperation_NewChoice] FOREIGN KEY([NewKVK], [SourceKey], [NewChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_NewChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [FK_SourceOutputOperation_NewChoice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_OldChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperation_OldChoice] FOREIGN KEY([OldKVK], [SourceKey], [OldChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_OldChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [FK_SourceOutputOperation_OldChoice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputOperation_Pool] FOREIGN KEY([PoolID], [AccountKey])
REFERENCES [KVK].[SourceOutputPool] ([PoolID], [AccountKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputOperation_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [FK_SourceOutputOperation_Pool]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Active]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Active] CHECK  (([State]='completed' AND [ActivePoolID] IS NULL OR [State]<>'completed' AND [ActivePoolID] IS NOT NULL AND [ActivePoolID]=[PoolID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Active]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Active]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Actor] CHECK  ((len([ConfirmedBy])>(0) AND datalength([ConfirmedBy])=datalength(ltrim(rtrim([ConfirmedBy]))) AND len([Reason])>(0) AND len([GuildID])>(0) AND NOT [GuildID] like ('%[^0-9]%') collate Latin1_General_100_BIN2 AND len([ChannelID])>(0) AND NOT [ChannelID] like ('%[^0-9]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Actor]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Counters] CHECK  (([EnqueueSequence]>(0) AND [Version]>(0) AND [UpdatedUTC]>=[ConfirmedUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Epoch]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Epoch] CHECK  (([OldEpoch]>(0) AND [TargetEpoch]>[OldEpoch] AND ([TargetEpoch]-[OldEpoch])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Epoch]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Epoch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_FilePhase]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_FilePhase] CHECK  ((([Phase]='setup_verified' OR [Phase]='setup_pending' OR [Phase]='clear_verified' OR [Phase]='clear_pending' OR [Phase]='private_verified' OR [Phase]='private_pending') AND [CurrentFileID] IS NOT NULL OR ([Phase]='uncertain' OR [Phase]='complete' OR [Phase]='ready' OR [Phase]='draining')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_FilePhase]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_FilePhase]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Owner]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Owner] CHECK  (([OwnerID] IS NULL AND [Fence]>=(0) AND ([State]='completed' OR [State]='blocked' OR [State]='ready' OR [State]='closing') OR [OwnerID] IS NOT NULL AND [Fence]>(0) AND ([State]='uncertain' OR [State]='blocked' OR [State]='running')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Owner]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Owner]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Phase]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Phase] CHECK  ((([Phase]='uncertain' OR [Phase]='complete' OR [Phase]='setup_verified' OR [Phase]='setup_pending' OR [Phase]='clear_verified' OR [Phase]='clear_pending' OR [Phase]='private_verified' OR [Phase]='private_pending' OR [Phase]='ready' OR [Phase]='draining') AND datalength([Phase])=len([Phase])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Phase]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Phase]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Plan]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Plan] CHECK  ((isjson([PlanJson])=(1) AND datalength([PlanJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Plan]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Plan]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Progress]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Progress] CHECK  ((isjson([ProgressJson])=(1) AND datalength([ProgressJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Progress]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Progress]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Source]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_Source] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [OldKVK]>(0) AND [NewKVK]>(0) AND [OldKVK]<>[NewKVK]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_Source]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_Source]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputOperation_State] CHECK  ((([State]='completed' OR [State]='uncertain' OR [State]='blocked' OR [State]='running' OR [State]='ready' OR [State]='closing') AND datalength([State])=len([State])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputOperation_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputOperation]'))
ALTER TABLE [KVK].[SourceOutputOperation] CHECK CONSTRAINT [CK_SourceOutputOperation_State]
