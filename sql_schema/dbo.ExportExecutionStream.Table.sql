SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportExecutionStream](
	[StreamID] [uniqueidentifier] NOT NULL,
	[SessionID] [uniqueidentifier] NOT NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActiveAccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[JobID] [uniqueidentifier] NULL,
	[PreparationID] [uniqueidentifier] NULL,
	[OutputOperationID] [uniqueidentifier] NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[ClaimVersion] [bigint] NOT NULL,
	[NestedToken] [uniqueidentifier] NULL,
	[RegistrationHash] [binary](32) NOT NULL,
	[Epoch] [bigint] NULL,
	[SnapshotHash] [binary](32) NOT NULL,
	[ScopeJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[Purpose] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[State] [varchar](16) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Version] [bigint] NOT NULL,
	[LastSequence] [bigint] NOT NULL,
	[ChildIdentity] [uniqueidentifier] NOT NULL,
	[ClosureHash] [binary](32) NULL,
	[ClosureReference] [uniqueidentifier] NULL,
	[EventDigest] [binary](32) NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
	[ClosedUTC] [datetime2](3) NULL,
 CONSTRAINT [PK_ExportExecutionStream] PRIMARY KEY CLUSTERED 
(
	[StreamID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportExecutionStream_Session] UNIQUE NONCLUSTERED 
(
	[StreamID] ASC,
	[SessionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]') AND name = N'IX_ExportExecutionStream_Owner')
CREATE NONCLUSTERED INDEX [IX_ExportExecutionStream_Owner] ON [dbo].[ExportExecutionStream]
(
	[AccountKey] ASC,
	[JobID] ASC,
	[PreparationID] ASC,
	[OutputOperationID] ASC,
	[State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]') AND name = N'IX_ExportExecutionStream_Session')
CREATE NONCLUSTERED INDEX [IX_ExportExecutionStream_Session] ON [dbo].[ExportExecutionStream]
(
	[SessionID] ASC,
	[State] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]') AND name = N'UX_ExportExecutionStream_ActiveAccount')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExportExecutionStream_ActiveAccount] ON [dbo].[ExportExecutionStream]
(
	[ActiveAccountKey] ASC
)
WHERE ([ActiveAccountKey] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [FK_ExportExecutionStream_Job] FOREIGN KEY([JobID])
REFERENCES [dbo].[ExportJob] ([JobID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [FK_ExportExecutionStream_Job]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Operation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [FK_ExportExecutionStream_Operation] FOREIGN KEY([OutputOperationID])
REFERENCES [KVK].[SourceOutputOperation] ([OperationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Operation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [FK_ExportExecutionStream_Operation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [FK_ExportExecutionStream_Preparation] FOREIGN KEY([PreparationID])
REFERENCES [dbo].[ExportPreparation] ([PreparationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [FK_ExportExecutionStream_Preparation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Session]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [FK_ExportExecutionStream_Session] FOREIGN KEY([SessionID])
REFERENCES [dbo].[ExportExecutionSession] ([SessionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportExecutionStream_Session]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [FK_ExportExecutionStream_Session]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Account]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_Account] CHECK  ((len([AccountKey])>(0) AND datalength([AccountKey])=len([AccountKey]) AND NOT [AccountKey] like ('%[^A-Za-z0-9_.@:-]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Account]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_Account]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_Counters] CHECK  (([ClaimVersion]>(0) AND [Version]>(0) AND [LastSequence]>=(0) AND ([Epoch] IS NULL OR [Epoch]>(0)) AND ([OwnerID] IS NOT NULL AND [Fence]>(0) OR [OwnerID] IS NULL AND [Fence]=(0) AND [OutputOperationID] IS NOT NULL AND [Purpose]='probe' AND [NestedToken] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Owner]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_Owner] CHECK  ((((case when [JobID] IS NULL then (0) else (1) end+case when [PreparationID] IS NULL then (0) else (1) end)+case when [OutputOperationID] IS NULL then (0) else (1) end)=(1) AND ([NestedToken] IS NULL OR [JobID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Owner]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_Owner]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Purpose]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_Purpose] CHECK  ((([Purpose]='enrollment' OR [Purpose]='probe' OR [Purpose]='mutation') AND datalength([Purpose])=len([Purpose])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Purpose]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_Purpose]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_Scope] CHECK  ((isjson([ScopeJson])=(1) AND datalength([ScopeJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream]  WITH CHECK ADD  CONSTRAINT [CK_ExportExecutionStream_State] CHECK  ((datalength([State])=len([State]) AND (([State]='frozen' OR [State]='open') AND [ActiveAccountKey] IS NOT NULL AND [ActiveAccountKey]=[AccountKey] AND datalength([ActiveAccountKey])=datalength([AccountKey]) AND [ClosedUTC] IS NULL AND [ClosureHash] IS NULL AND [ClosureReference] IS NULL AND [EventDigest] IS NULL OR [State]='closed' AND [ActiveAccountKey] IS NULL AND [ClosedUTC]>=[CreatedUTC] AND [ClosureHash] IS NOT NULL AND [ClosureReference] IS NOT NULL AND [EventDigest] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportExecutionStream_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportExecutionStream]'))
ALTER TABLE [dbo].[ExportExecutionStream] CHECK CONSTRAINT [CK_ExportExecutionStream_State]
