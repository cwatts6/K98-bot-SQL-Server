SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportAttempt]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportAttempt](
	[AttemptID] [uniqueidentifier] NOT NULL,
	[JobID] [uniqueidentifier] NOT NULL,
	[ConsumerKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AttemptNo] [bigint] NOT NULL,
	[OwnerID] [uniqueidentifier] NOT NULL,
	[Fence] [bigint] NOT NULL,
	[Epoch] [bigint] NULL,
	[Phase] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RemoteSequence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
	[VerifiedUTC] [datetime2](0) NULL,
	[PublishedUTC] [datetime2](0) NULL,
	[ManifestHash] [binary](32) NOT NULL,
	[ManifestJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[ReceiptJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[PartCount] [int] NOT NULL,
	[LegacyPublicationID] [uniqueidentifier] NULL,
	[LegacySourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[LegacyKVK_NO] [int] NULL,
	[LegacyPeriodID] [uniqueidentifier] NULL,
	[LegacyDestinationKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NULL,
	[LegacyDestinationID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
 CONSTRAINT [PK_ExportAttempt] PRIMARY KEY CLUSTERED 
(
	[AttemptID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportAttempt_JobEpoch] UNIQUE NONCLUSTERED 
(
	[AttemptID] ASC,
	[JobID] ASC,
	[Epoch] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportAttempt_PartCount] UNIQUE NONCLUSTERED 
(
	[AttemptID] ASC,
	[PartCount] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportAttempt_Sequence] UNIQUE NONCLUSTERED 
(
	[JobID] ASC,
	[AttemptNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportAttempt]') AND name = N'IX_ExportAttempt_Phase')
CREATE NONCLUSTERED INDEX [IX_ExportAttempt_Phase] ON [dbo].[ExportAttempt]
(
	[Phase] ASC,
	[UpdatedUTC] ASC,
	[JobID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_Epoch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttempt_Epoch] FOREIGN KEY([JobID], [Epoch])
REFERENCES [dbo].[ExportJob] ([JobID], [PoolEpoch])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_Epoch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [FK_ExportAttempt_Epoch]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttempt_Job] FOREIGN KEY([JobID], [ConsumerKind])
REFERENCES [dbo].[ExportJob] ([JobID], [ConsumerKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [FK_ExportAttempt_Job]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacyDelivery]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttempt_LegacyDelivery] FOREIGN KEY([LegacyPublicationID], [LegacyDestinationKind], [LegacyDestinationID])
REFERENCES [KVK].[SourceDelivery] ([PublicationID], [DestinationKind], [DestinationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacyDelivery]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [FK_ExportAttempt_LegacyDelivery]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacyPublication]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttempt_LegacyPublication] FOREIGN KEY([LegacySourceKey], [LegacyKVK_NO], [LegacyPeriodID], [LegacyPublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacyPublication]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [FK_ExportAttempt_LegacyPublication]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacySeason]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [FK_ExportAttempt_LegacySeason] FOREIGN KEY([JobID], [LegacyKVK_NO])
REFERENCES [dbo].[ExportJob] ([JobID], [KVK_NO])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportAttempt_LegacySeason]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [FK_ExportAttempt_LegacySeason]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Consumer] CHECK  ((datalength([ConsumerKind])=len([ConsumerKind]) AND ([ConsumerKind]='scan_data' OR [ConsumerKind]='all_kvk' OR [ConsumerKind]='new_source')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Consumer]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Consumer]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Counters] CHECK  (([AttemptNo]>(0) AND [Fence]>(0) AND [RemoteSequence]>(0) AND [Version]>(0) AND ([PartCount]>=(1) AND [PartCount]<=(1024))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Counters]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Epoch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Epoch] CHECK  (([ConsumerKind]='new_source' AND [Epoch] IS NOT NULL AND [Epoch]>(0) OR ([ConsumerKind]='scan_data' OR [ConsumerKind]='all_kvk') AND [Epoch] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Epoch]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Epoch]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Evidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Evidence] CHECK  (((NOT ([Phase]='retired' OR [Phase]='published' OR [Phase]='publication_pending' OR [Phase]='verified') OR [VerifiedUTC] IS NOT NULL) AND (NOT ([Phase]='retired' OR [Phase]='published') OR [PublishedUTC] IS NOT NULL AND [ReceiptJson] IS NOT NULL) AND ([Phase]<>'private_started' OR [VerifiedUTC] IS NULL AND [PublishedUTC] IS NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Evidence]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Evidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Legacy]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Legacy] CHECK  (([LegacyPublicationID] IS NULL AND [LegacySourceKey] IS NULL AND [LegacyKVK_NO] IS NULL AND [LegacyPeriodID] IS NULL AND [LegacyDestinationKind] IS NULL AND [LegacyDestinationID] IS NULL OR [ConsumerKind]='new_source' AND [LegacyPublicationID] IS NOT NULL AND [LegacySourceKey] IS NOT NULL AND [LegacySourceKey]='snapshot_report_v1' AND datalength([LegacySourceKey])=(18) AND [LegacyKVK_NO] IS NOT NULL AND [LegacyKVK_NO]>(0) AND [LegacyPeriodID] IS NOT NULL AND [LegacyDestinationKind] IS NOT NULL AND datalength([LegacyDestinationKind])=len([LegacyDestinationKind]) AND ([LegacyDestinationKind]='file' OR [LegacyDestinationKind]='sheets' OR [LegacyDestinationKind]='discord') AND [LegacyDestinationID] IS NOT NULL AND len([LegacyDestinationID])>(0) AND datalength([LegacyDestinationID])=datalength(ltrim(rtrim([LegacyDestinationID])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Legacy]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Legacy]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Manifest]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Manifest] CHECK  ((isjson([ManifestJson])=(1) AND datalength([ManifestJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Manifest]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Manifest]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Phase]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Phase] CHECK  ((datalength([Phase])=len([Phase]) AND ([Phase]='retired' OR [Phase]='uncertain' OR [Phase]='failed' OR [Phase]='published' OR [Phase]='publication_pending' OR [Phase]='verified' OR [Phase]='private_started')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Phase]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Phase]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Receipt]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Receipt] CHECK  (([ReceiptJson] IS NULL OR isjson([ReceiptJson])=(1) AND datalength([ReceiptJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Receipt]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Receipt]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Time]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt]  WITH CHECK ADD  CONSTRAINT [CK_ExportAttempt_Time] CHECK  (([UpdatedUTC]>=[CreatedUTC] AND ([VerifiedUTC] IS NULL OR [VerifiedUTC]>=[CreatedUTC] AND [VerifiedUTC]<=[UpdatedUTC]) AND ([PublishedUTC] IS NULL OR [VerifiedUTC] IS NOT NULL AND ([PublishedUTC]>=[VerifiedUTC] AND [PublishedUTC]<=[UpdatedUTC]))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportAttempt_Time]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportAttempt]'))
ALTER TABLE [dbo].[ExportAttempt] CHECK CONSTRAINT [CK_ExportAttempt_Time]
