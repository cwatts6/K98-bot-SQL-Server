SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputDisposition](
	[DispositionID] [uniqueidentifier] NOT NULL,
	[OperationID] [uniqueidentifier] NOT NULL,
	[PoolID] [uniqueidentifier] NOT NULL,
	[SequenceNo] [bigint] NOT NULL,
	[FileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[FileKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SlotFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[IndexFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ChoiceID] [uniqueidentifier] NOT NULL,
	[NewKVK_NO] [int] NOT NULL,
	[NewChoiceID] [uniqueidentifier] NOT NULL,
	[OldEpoch] [bigint] NOT NULL,
	[NewEpoch] [bigint] NOT NULL,
	[Action] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OwnerID] [uniqueidentifier] NOT NULL,
	[Fence] [bigint] NOT NULL,
	[FromPoolVersion] [bigint] NOT NULL,
	[ToPoolVersion] [bigint] NOT NULL,
	[FromSlotVersion] [bigint] NULL,
	[ToSlotVersion] [bigint] NULL,
	[JobID] [uniqueidentifier] NULL,
	[ConsumerKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[DestinationSetHash] [binary](32) NULL,
	[AttemptID] [uniqueidentifier] NULL,
	[PartNo] [int] NULL,
	[AttemptEpoch] [bigint] NULL,
	[LegacyPublicationID] [uniqueidentifier] NULL,
	[LegacyPeriodID] [uniqueidentifier] NULL,
	[LegacyDestinationKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[LegacyDestinationID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[Actor] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[OccurredUTC] [datetime2](0) NOT NULL,
	[EvidenceHash] [binary](32) NOT NULL,
	[EvidenceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceOutputDisposition] PRIMARY KEY CLUSTERED 
(
	[DispositionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputDisposition_Assignment] UNIQUE NONCLUSTERED 
(
	[DispositionID] ASC,
	[PoolID] ASC,
	[FileID] ASC,
	[NewEpoch] ASC,
	[AttemptID] ASC,
	[PartNo] ASC,
	[ToSlotVersion] ASC,
	[Action] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputDisposition_Current] UNIQUE NONCLUSTERED 
(
	[DispositionID] ASC,
	[PoolID] ASC,
	[FileID] ASC,
	[NewEpoch] ASC,
	[Action] ASC,
	[ToSlotVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputDisposition_Replay] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[OperationID] ASC,
	[FileID] ASC,
	[Action] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputDisposition_Sequence] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[SequenceNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]') AND name = N'IX_SourceOutputDisposition_Attempt')
CREATE NONCLUSTERED INDEX [IX_SourceOutputDisposition_Attempt] ON [KVK].[SourceOutputDisposition]
(
	[AttemptID] ASC,
	[PartNo] ASC
)
WHERE ([AttemptID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]') AND name = N'IX_SourceOutputDisposition_FileHistory')
CREATE NONCLUSTERED INDEX [IX_SourceOutputDisposition_FileHistory] ON [KVK].[SourceOutputDisposition]
(
	[PoolID] ASC,
	[FileID] ASC,
	[SequenceNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Attempt]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Attempt] FOREIGN KEY([AttemptID], [JobID], [AttemptEpoch])
REFERENCES [dbo].[ExportAttempt] ([AttemptID], [JobID], [Epoch])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Attempt]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Attempt]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Choice] FOREIGN KEY([KVK_NO], [SourceKey], [ChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Choice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_File] FOREIGN KEY([FileID], [FileKind])
REFERENCES [KVK].[SourceOutputFile] ([FileID], [FileKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_File]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Index] FOREIGN KEY([PoolID], [IndexFileID])
REFERENCES [KVK].[SourceOutputPool] ([PoolID], [IndexFileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Index]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Job]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Job] FOREIGN KEY([JobID], [ConsumerKind], [AccountKey], [KVK_NO], [DestinationSetHash], [AttemptEpoch])
REFERENCES [dbo].[ExportJob] ([JobID], [ConsumerKind], [AccountKey], [KVK_NO], [DestinationSetHash], [PoolEpoch])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Job]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Job]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyDelivery]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_LegacyDelivery] FOREIGN KEY([LegacyPublicationID], [LegacyDestinationKind], [LegacyDestinationID])
REFERENCES [KVK].[SourceDelivery] ([PublicationID], [DestinationKind], [DestinationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyDelivery]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_LegacyDelivery]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyIndex]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_LegacyIndex] FOREIGN KEY([PoolID], [LegacyDestinationID])
REFERENCES [KVK].[SourceOutputPool] ([PoolID], [IndexFileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyIndex]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_LegacyIndex]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyPublication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_LegacyPublication] FOREIGN KEY([SourceKey], [KVK_NO], [LegacyPeriodID], [LegacyPublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_LegacyPublication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_LegacyPublication]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Membership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Membership] FOREIGN KEY([JobID], [ResourceKey])
REFERENCES [dbo].[ExportJobResource] ([JobID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Membership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Membership]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_NewChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_NewChoice] FOREIGN KEY([NewKVK_NO], [SourceKey], [NewChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_NewChoice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_NewChoice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Part]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Part] FOREIGN KEY([AttemptID], [PartNo], [FileID])
REFERENCES [dbo].[ExportAttemptPart] ([AttemptID], [PartNo], [FileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Part]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Part]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Pool] FOREIGN KEY([PoolID], [AccountKey])
REFERENCES [KVK].[SourceOutputPool] ([PoolID], [AccountKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Pool]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Resource] FOREIGN KEY([FileID], [ResourceKey])
REFERENCES [KVK].[SourceOutputFile] ([FileID], [ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Resource]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Resource]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Slot]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputDisposition_Slot] FOREIGN KEY([PoolID], [SlotFileID])
REFERENCES [KVK].[SourceOutputSlot] ([PoolID], [FileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputDisposition_Slot]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [FK_SourceOutputDisposition_Slot]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Action]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Action] CHECK  ((([Action]='assign' OR [Action]='clear' OR [Action]='quarantine' OR [Action]='retire') AND datalength([Action])=len([Action])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Action]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Action]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Actor] CHECK  ((len([Actor])>(0) AND datalength([Actor])=datalength(ltrim(rtrim([Actor]))) AND len([Reason])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Actor]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Actor]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Attempt]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Attempt] CHECK  (([JobID] IS NULL AND [ConsumerKind] IS NULL AND [DestinationSetHash] IS NULL AND [AttemptID] IS NULL AND [PartNo] IS NULL AND [AttemptEpoch] IS NULL AND [Action]<>'assign' OR [JobID] IS NOT NULL AND [ConsumerKind] IS NOT NULL AND [ConsumerKind]='new_source' AND datalength([ConsumerKind])=(10) AND [DestinationSetHash] IS NOT NULL AND [AttemptID] IS NOT NULL AND [PartNo] IS NOT NULL AND ([PartNo]>=(1) AND [PartNo]<=(1024)) AND [AttemptEpoch] IS NOT NULL AND [AttemptEpoch]=[OldEpoch]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Attempt]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Attempt]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Epoch]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Epoch] CHECK  (([OldEpoch]>(0) AND [NewEpoch]>=[OldEpoch] AND (([NewEpoch]-[OldEpoch])>=(0) AND ([NewEpoch]-[OldEpoch])<=(1)) AND ([NewEpoch]=[OldEpoch] AND [NewKVK_NO]=[KVK_NO] AND [NewChoiceID]=[ChoiceID] OR [NewEpoch]>[OldEpoch] AND [Action]='clear')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Epoch]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Epoch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Evidence] CHECK  ((isjson([EvidenceJson])=(1) AND datalength([EvidenceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Evidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_File] CHECK  (([FileKind]='slot' AND datalength([FileKind])=(4) AND [SlotFileID] IS NOT NULL AND [SlotFileID]=[FileID] AND datalength([SlotFileID])=datalength([FileID]) AND [IndexFileID] IS NULL AND [FromSlotVersion] IS NOT NULL AND [ToSlotVersion] IS NOT NULL AND [FromSlotVersion]>(0) AND [ToSlotVersion]>[FromSlotVersion] AND ([ToSlotVersion]-[FromSlotVersion])=(1) OR [FileKind]='index' AND datalength([FileKind])=(5) AND [IndexFileID] IS NOT NULL AND [IndexFileID]=[FileID] AND datalength([IndexFileID])=datalength([FileID]) AND [SlotFileID] IS NULL AND [FromSlotVersion] IS NULL AND [ToSlotVersion] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_File]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Legacy]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Legacy] CHECK  (([LegacyPublicationID] IS NULL AND [LegacyPeriodID] IS NULL AND [LegacyDestinationKind] IS NULL AND [LegacyDestinationID] IS NULL OR [LegacyPublicationID] IS NOT NULL AND [LegacyPeriodID] IS NOT NULL AND [LegacyDestinationKind] IS NOT NULL AND [LegacyDestinationKind]='sheets' AND datalength([LegacyDestinationKind])=(6) AND [LegacyDestinationID] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Legacy]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Legacy]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Owner]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Owner] CHECK  (([Fence]>(0) AND [SequenceNo]>(0) AND [FromPoolVersion]>(0) AND [ToPoolVersion]>[FromPoolVersion] AND ([ToPoolVersion]-[FromPoolVersion])=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Owner]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Owner]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputDisposition_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0) AND [NewKVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputDisposition_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputDisposition]'))
ALTER TABLE [KVK].[SourceOutputDisposition] CHECK CONSTRAINT [CK_SourceOutputDisposition_Scope]
