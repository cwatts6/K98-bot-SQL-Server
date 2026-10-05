SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportJob]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportJob](
	[JobID] [uniqueidentifier] NOT NULL,
	[ConsumerKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[IntentID] [uniqueidentifier] NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[DestinationSetHash] [binary](32) NOT NULL,
	[InputHash] [binary](32) NOT NULL,
	[SpoolKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[SpoolBytes] [bigint] NULL,
	[StorageOwner] [varchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[KVK_NO] [int] NULL,
	[PoolEpoch] [bigint] NULL,
	[RepairID] [uniqueidentifier] NULL,
	[EnqueueSequence] [bigint] NOT NULL,
	[State] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
	[SupersededByJobID] [uniqueidentifier] NULL,
	[Actor] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_ExportJob] PRIMARY KEY CLUSTERED 
(
	[JobID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportJob_Consumer] UNIQUE NONCLUSTERED 
(
	[JobID] ASC,
	[ConsumerKind] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportJob_Epoch] UNIQUE NONCLUSTERED 
(
	[JobID] ASC,
	[PoolEpoch] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportJob_Replay] UNIQUE NONCLUSTERED 
(
	[ConsumerKind] ASC,
	[AccountKey] ASC,
	[KVK_NO] ASC,
	[InputHash] ASC,
	[DestinationSetHash] ASC,
	[PoolEpoch] ASC,
	[RepairID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportJob_Season] UNIQUE NONCLUSTERED 
(
	[JobID] ASC,
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportJob_SupersessionScope] UNIQUE NONCLUSTERED 
(
	[JobID] ASC,
	[ConsumerKind] ASC,
	[AccountKey] ASC,
	[KVK_NO] ASC,
	[DestinationSetHash] ASC,
	[PoolEpoch] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportJob]') AND name = N'IX_ExportJob_Intent')
CREATE NONCLUSTERED INDEX [IX_ExportJob_Intent] ON [dbo].[ExportJob]
(
	[IntentID] ASC
)
WHERE ([IntentID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportJob]') AND name = N'IX_ExportJob_Queue')
CREATE NONCLUSTERED INDEX [IX_ExportJob_Queue] ON [dbo].[ExportJob]
(
	[AccountKey] ASC,
	[State] ASC,
	[EnqueueSequence] ASC,
	[JobID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportJob]') AND name = N'IX_ExportJob_Superseded')
CREATE NONCLUSTERED INDEX [IX_ExportJob_Superseded] ON [dbo].[ExportJob]
(
	[SupersededByJobID] ASC
)
WHERE ([SupersededByJobID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJob_Intent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [FK_ExportJob_Intent] FOREIGN KEY([SourceKey], [KVK_NO], [IntentID])
REFERENCES [KVK].[SourceExportIntent] ([SourceKey], [KVK_NO], [IntentID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJob_Intent]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [FK_ExportJob_Intent]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJob_Superseded]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [FK_ExportJob_Superseded] FOREIGN KEY([SupersededByJobID], [ConsumerKind], [AccountKey], [KVK_NO], [DestinationSetHash], [PoolEpoch])
REFERENCES [dbo].[ExportJob] ([JobID], [ConsumerKind], [AccountKey], [KVK_NO], [DestinationSetHash], [PoolEpoch])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJob_Superseded]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [FK_ExportJob_Superseded]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Consumer] CHECK  ((datalength([ConsumerKind])=len([ConsumerKind]) AND ([ConsumerKind]='scan_data' OR [ConsumerKind]='all_kvk' OR [ConsumerKind]='new_source')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Consumer]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Counters] CHECK  (([EnqueueSequence]>(0) AND [Version]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Identity] CHECK  ((len([AccountKey])>(0) AND datalength([AccountKey])=datalength(ltrim(rtrim([AccountKey]))) AND len([Actor])>(0) AND datalength([Actor])=datalength(ltrim(rtrim([Actor]))) AND len([Reason])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Identity]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Ownership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Ownership] CHECK  (([Fence]>=(0) AND ([OwnerID] IS NULL AND [Fence]=(0) AND ([State]='cancelled' OR [State]='coalesced' OR [State]='ready' OR [State]='waiting') OR [OwnerID] IS NOT NULL AND [Fence]>(0) AND ([State]='uncertain' OR [State]='failed' OR [State]='confirmed' OR [State]='running'))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Ownership]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Ownership]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Provenance]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Provenance] CHECK  ((isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Provenance]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Scope] CHECK  (([ConsumerKind]='new_source' AND [SourceKey] IS NOT NULL AND [SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [IntentID] IS NOT NULL AND [KVK_NO] IS NOT NULL AND [KVK_NO]>(0) AND [PoolEpoch] IS NOT NULL AND [PoolEpoch]>(0) OR [ConsumerKind]='all_kvk' AND [SourceKey] IS NULL AND [IntentID] IS NULL AND [KVK_NO] IS NOT NULL AND [KVK_NO]>(0) AND [PoolEpoch] IS NULL OR [ConsumerKind]='scan_data' AND [SourceKey] IS NULL AND [IntentID] IS NULL AND [KVK_NO] IS NULL AND [PoolEpoch] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Spool]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Spool] CHECK  (([SpoolKey] IS NULL AND [SpoolBytes] IS NULL AND [StorageOwner] IS NULL AND [ConsumerKind]='new_source' OR [SpoolKey] IS NOT NULL AND [SpoolBytes] IS NOT NULL AND [StorageOwner] IS NOT NULL AND [SpoolBytes]>(0) AND len([SpoolKey])>(0) AND datalength([SpoolKey])=datalength(ltrim(rtrim([SpoolKey]))) AND len([StorageOwner])>(0) AND datalength([StorageOwner])=datalength(ltrim(rtrim([StorageOwner]))) AND NOT [SpoolKey] like ('%[^a-zA-Z0-9_-]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Spool]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Spool]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_State] CHECK  ((datalength([State])=len([State]) AND ([State]='cancelled' OR [State]='coalesced' OR [State]='uncertain' OR [State]='failed' OR [State]='confirmed' OR [State]='running' OR [State]='ready' OR [State]='waiting')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Supersession]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Supersession] CHECK  (([State]='coalesced' AND [ConsumerKind]='new_source' AND [SupersededByJobID] IS NOT NULL AND [SupersededByJobID]<>[JobID] OR [State]<>'coalesced' AND [SupersededByJobID] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Supersession]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Supersession]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Time]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob]  WITH CHECK ADD  CONSTRAINT [CK_ExportJob_Time] CHECK  (([UpdatedUTC]>=[CreatedUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportJob_Time]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJob]'))
ALTER TABLE [dbo].[ExportJob] CHECK CONSTRAINT [CK_ExportJob_Time]
