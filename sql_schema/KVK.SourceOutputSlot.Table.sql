SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputSlot](
	[FileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[FileKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[PoolID] [uniqueidentifier] NOT NULL,
	[SlotNo] [int] NOT NULL,
	[Epoch] [bigint] NOT NULL,
	[State] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[AssignmentID] [uniqueidentifier] NULL,
	[AssignmentAction] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[AttemptID] [uniqueidentifier] NULL,
	[PartNo] [int] NULL,
	[AssignmentVersion] [bigint] NULL,
	[LastDispositionID] [uniqueidentifier] NULL,
	[LastAction] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[LastDispositionVersion] [bigint] NULL,
	[QuarantineReason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_SourceOutputSlot] PRIMARY KEY CLUSTERED 
(
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputSlot_PoolFile] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[FileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputSlot_Position] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[SlotNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]') AND name = N'IX_SourceOutputSlot_Attempt')
CREATE NONCLUSTERED INDEX [IX_SourceOutputSlot_Attempt] ON [KVK].[SourceOutputSlot]
(
	[AttemptID] ASC,
	[PartNo] ASC
)
WHERE ([AttemptID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]') AND name = N'IX_SourceOutputSlot_Availability')
CREATE NONCLUSTERED INDEX [IX_SourceOutputSlot_Availability] ON [KVK].[SourceOutputSlot]
(
	[PoolID] ASC,
	[Epoch] ASC,
	[State] ASC,
	[SlotNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Assignment]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputSlot_Assignment] FOREIGN KEY([AssignmentID], [PoolID], [FileID], [Epoch], [AttemptID], [PartNo], [AssignmentVersion], [AssignmentAction])
REFERENCES [KVK].[SourceOutputDisposition] ([DispositionID], [PoolID], [FileID], [NewEpoch], [AttemptID], [PartNo], [ToSlotVersion], [Action])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Assignment]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [FK_SourceOutputSlot_Assignment]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Disposition]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputSlot_Disposition] FOREIGN KEY([LastDispositionID], [PoolID], [FileID], [Epoch], [LastAction], [LastDispositionVersion])
REFERENCES [KVK].[SourceOutputDisposition] ([DispositionID], [PoolID], [FileID], [NewEpoch], [Action], [ToSlotVersion])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Disposition]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [FK_SourceOutputSlot_Disposition]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputSlot_File] FOREIGN KEY([FileID], [FileKind])
REFERENCES [KVK].[SourceOutputFile] ([FileID], [FileKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_File]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [FK_SourceOutputSlot_File]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Part]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputSlot_Part] FOREIGN KEY([AttemptID], [PartNo], [FileID])
REFERENCES [dbo].[ExportAttemptPart] ([AttemptID], [PartNo], [FileID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Part]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [FK_SourceOutputSlot_Part]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputSlot_Pool] FOREIGN KEY([PoolID])
REFERENCES [KVK].[SourceOutputPool] ([PoolID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputSlot_Pool]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [FK_SourceOutputSlot_Pool]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Assignment]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Assignment] CHECK  (([AssignmentID] IS NULL AND [AssignmentAction] IS NULL AND [AttemptID] IS NULL AND [PartNo] IS NULL AND [AssignmentVersion] IS NULL AND ([State]='retired' OR [State]='quarantined' OR [State]='free') OR [AssignmentID] IS NOT NULL AND [AssignmentAction] IS NOT NULL AND [AssignmentAction]='assign' AND datalength([AssignmentAction])=(6) AND [AttemptID] IS NOT NULL AND [PartNo] IS NOT NULL AND ([PartNo]>=(1) AND [PartNo]<=(1024)) AND [AssignmentVersion] IS NOT NULL AND [AssignmentVersion]>(0) AND [AssignmentVersion]<=[Version] AND [State]<>'free'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Assignment]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Assignment]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Counters] CHECK  (([SlotNo]>=(1) AND [SlotNo]<=(16) AND [Epoch]>(0) AND [Version]>(0) AND [UpdatedUTC]>=[CreatedUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Disposition]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Disposition] CHECK  (([LastDispositionID] IS NULL AND [LastAction] IS NULL AND [LastDispositionVersion] IS NULL AND [State]='quarantined' AND [AssignmentID] IS NULL OR [LastDispositionID] IS NOT NULL AND [LastAction] IS NOT NULL AND datalength([LastAction])=len([LastAction]) AND [LastDispositionVersion] IS NOT NULL AND [LastDispositionVersion]>(0) AND [LastDispositionVersion]<=[Version] AND ([State]='free' AND [LastAction]='clear' OR ([State]='active' OR [State]='staging') AND [LastAction]='assign' AND [LastDispositionID]=[AssignmentID] OR [State]='quarantined' AND [LastAction]='quarantine' OR [State]='retired' AND [LastAction]='retire')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Disposition]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Disposition]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Kind] CHECK  (([FileKind]='slot' AND datalength([FileKind])=(4)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Kind]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Kind]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Ownership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Ownership] CHECK  (([OwnerID] IS NULL AND [Fence]>=(0) AND [State]<>'staging' OR [OwnerID] IS NOT NULL AND [Fence]>(0) AND ([State]='quarantined' OR [State]='active' OR [State]='staging')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Ownership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Ownership]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Quarantine]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_Quarantine] CHECK  (([State]='quarantined' AND [QuarantineReason] IS NOT NULL AND len([QuarantineReason])>(0) OR [State]<>'quarantined' AND [QuarantineReason] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_Quarantine]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_Quarantine]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputSlot_State] CHECK  ((([State]='retired' OR [State]='quarantined' OR [State]='active' OR [State]='staging' OR [State]='free') AND datalength([State])=len([State])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputSlot_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputSlot]'))
ALTER TABLE [KVK].[SourceOutputSlot] CHECK CONSTRAINT [CK_SourceOutputSlot_State]
