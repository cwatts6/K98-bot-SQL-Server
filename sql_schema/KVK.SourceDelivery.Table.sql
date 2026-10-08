SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceDelivery]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceDelivery](
	[PublicationID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[DestinationKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[DestinationID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[DeliveryState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AttemptCount] [int] NOT NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Receipt] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
	[ClaimedUTC] [datetime2](0) NULL,
	[ConfirmedUTC] [datetime2](0) NULL,
 CONSTRAINT [PK_SourceDelivery] PRIMARY KEY CLUSTERED 
(
	[PublicationID] ASC,
	[DestinationKind] ASC,
	[DestinationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceDelivery]') AND name = N'IX_SourceDelivery_State')
CREATE NONCLUSTERED INDEX [IX_SourceDelivery_State] ON [KVK].[SourceDelivery]
(
	[DeliveryState] ASC,
	[UpdatedUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceDelivery_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery]  WITH CHECK ADD  CONSTRAINT [FK_SourceDelivery_Publication] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceDelivery_Publication]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery] CHECK CONSTRAINT [FK_SourceDelivery_Publication]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Destination]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery]  WITH CHECK ADD  CONSTRAINT [CK_SourceDelivery_Destination] CHECK  ((([DestinationKind]='file' OR [DestinationKind]='sheets' OR [DestinationKind]='discord') AND datalength([DestinationKind])=len([DestinationKind]) AND len([DestinationID])>(0) AND datalength([DestinationID])=datalength(ltrim(rtrim([DestinationID])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Destination]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery] CHECK CONSTRAINT [CK_SourceDelivery_Destination]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery]  WITH CHECK ADD  CONSTRAINT [CK_SourceDelivery_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery] CHECK CONSTRAINT [CK_SourceDelivery_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery]  WITH CHECK ADD  CONSTRAINT [CK_SourceDelivery_State] CHECK  ((datalength([DeliveryState])=len([DeliveryState]) AND ([DeliveryState]='pending' AND [AttemptCount]=(0) AND [Fence]=(0) AND [OwnerID] IS NULL AND [ClaimedUTC] IS NULL AND [ConfirmedUTC] IS NULL AND [Receipt] IS NULL OR ([DeliveryState]='uncertain' OR [DeliveryState]='failed' OR [DeliveryState]='claimed') AND [AttemptCount]>(0) AND [Fence]>(0) AND [OwnerID] IS NOT NULL AND [ClaimedUTC] IS NOT NULL AND [ConfirmedUTC] IS NULL OR [DeliveryState]='confirmed' AND [AttemptCount]>(0) AND [Fence]>(0) AND [OwnerID] IS NOT NULL AND [ClaimedUTC] IS NOT NULL AND [ConfirmedUTC] IS NOT NULL AND [Receipt] IS NOT NULL AND len([Receipt])>(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery] CHECK CONSTRAINT [CK_SourceDelivery_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery]  WITH CHECK ADD  CONSTRAINT [CK_SourceDelivery_Time] CHECK  (([UpdatedUTC]>=[CreatedUTC] AND ([ClaimedUTC] IS NULL OR [ClaimedUTC]>=[CreatedUTC] AND [ClaimedUTC]<=[UpdatedUTC]) AND ([ConfirmedUTC] IS NULL OR [ConfirmedUTC]>=[ClaimedUTC] AND [ConfirmedUTC]<=[UpdatedUTC])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceDelivery_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceDelivery]'))
ALTER TABLE [KVK].[SourceDelivery] CHECK CONSTRAINT [CK_SourceDelivery_Time]
