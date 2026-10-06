SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportPreparation]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportPreparation](
	[PreparationID] [uniqueidentifier] NOT NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ConsumerKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NULL,
	[RequestHash] [binary](32) NOT NULL,
	[EnqueueSequence] [bigint] NOT NULL,
	[State] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[StorageOwner] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RequestJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[GenerationJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[SpoolKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[SpoolBytes] [bigint] NULL,
	[SpoolHash] [binary](32) NULL,
	[JobID] [uniqueidentifier] NULL,
	[Actor] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
	[UpdatedUTC] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ExportPreparation] PRIMARY KEY CLUSTERED 
(
	[PreparationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportPreparation_Replay] UNIQUE NONCLUSTERED 
(
	[AccountKey] ASC,
	[RequestHash] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportPreparation]') AND name = N'IX_ExportPreparation_Queue')
CREATE NONCLUSTERED INDEX [IX_ExportPreparation_Queue] ON [dbo].[ExportPreparation]
(
	[AccountKey] ASC,
	[State] ASC,
	[EnqueueSequence] ASC,
	[PreparationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportPreparation]') AND name = N'UX_ExportPreparation_Job')
CREATE UNIQUE NONCLUSTERED INDEX [UX_ExportPreparation_Job] ON [dbo].[ExportPreparation]
(
	[JobID] ASC
)
WHERE ([JobID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparation_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [FK_ExportPreparation_Job] FOREIGN KEY([JobID])
REFERENCES [dbo].[ExportJob] ([JobID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparation_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [FK_ExportPreparation_Job]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Consumer] CHECK  ((([ConsumerKind]='config' OR [ConsumerKind]='scan_data' OR [ConsumerKind]='all_kvk') AND datalength([ConsumerKind])=len([ConsumerKind])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Consumer]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Counters] CHECK  (([Version]>(0) AND [EnqueueSequence]>(0) AND [UpdatedUTC]>=[CreatedUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Generation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Generation] CHECK  (([GenerationJson] IS NULL AND NOT ([State]='materialized' OR [State]='captured' OR [State]='committed') OR [GenerationJson] IS NOT NULL AND isjson([GenerationJson])=(1) AND datalength([GenerationJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Generation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Generation]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Job] CHECK  (([JobID] IS NULL AND [State]<>'materialized' OR [JobID] IS NOT NULL AND [State]='materialized' AND [ConsumerKind]<>'config'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Job]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Owner]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Owner] CHECK  (([OwnerID] IS NULL AND [Fence]=(0) AND [State]='pending' OR [OwnerID] IS NOT NULL AND [Fence]>(0) AND [State]<>'pending'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Owner]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Owner]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Request] CHECK  ((isjson([RequestJson])=(1) AND datalength([RequestJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Request]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Scope] CHECK  (([ConsumerKind]='all_kvk' AND [KVK_NO] IS NOT NULL AND [KVK_NO]>(0) OR ([ConsumerKind]='config' OR [ConsumerKind]='scan_data') AND [KVK_NO] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Scope]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Spool]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Spool] CHECK  (([SpoolKey] IS NULL AND [SpoolBytes] IS NULL AND [SpoolHash] IS NULL AND NOT ([State]='materialized' OR [State]='captured') OR [SpoolKey] IS NOT NULL AND [SpoolBytes] IS NOT NULL AND [SpoolHash] IS NOT NULL AND [SpoolBytes]>(0) AND len([SpoolKey])>(0) AND datalength([SpoolKey])=datalength(ltrim(rtrim([SpoolKey]))) AND NOT [SpoolKey] like ('%[^a-zA-Z0-9_-]%') collate Latin1_General_100_BIN2))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Spool]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Spool]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_State] CHECK  ((([State]='uncertain' OR [State]='unavailable' OR [State]='completed' OR [State]='materialized' OR [State]='captured' OR [State]='committed' OR [State]='writing' OR [State]='sql_pending' OR [State]='preflight' OR [State]='pending') AND datalength([State])=len([State])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Text]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation]  WITH CHECK ADD  CONSTRAINT [CK_ExportPreparation_Text] CHECK  ((len([AccountKey])>(0) AND datalength([AccountKey])=datalength(ltrim(rtrim([AccountKey]))) AND len([StorageOwner])>(0) AND datalength([StorageOwner])=datalength(ltrim(rtrim([StorageOwner]))) AND len([Actor])>(0) AND len([Reason])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportPreparation_Text]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparation]'))
ALTER TABLE [dbo].[ExportPreparation] CHECK CONSTRAINT [CK_ExportPreparation_Text]
