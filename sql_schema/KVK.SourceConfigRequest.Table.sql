SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceConfigRequest](
	[RequestID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[PeriodID] [uniqueidentifier] NOT NULL,
	[PeriodKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[BaseConfigVersionID] [uniqueidentifier] NOT NULL,
	[DesiredConfigVersionID] [uniqueidentifier] NOT NULL,
	[ConfigContentHash] [binary](32) NOT NULL,
	[OldStartScanID] [int] NULL,
	[OldEndScanID] [int] NULL,
	[NewStartScanID] [int] NULL,
	[NewEndScanID] [int] NULL,
	[Origin] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Actor] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RequestedUTC] [datetime2](0) NOT NULL,
	[RequestState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AppliedPublicationID] [uniqueidentifier] NULL,
	[CompletedUTC] [datetime2](0) NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceConfigRequest] PRIMARY KEY CLUSTERED 
(
	[RequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceConfigRequest_Replay] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[ConfigContentHash] ASC,
	[BaseConfigVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceConfigRequest_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[PeriodID] ASC,
	[RequestID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]') AND name = N'IX_SourceConfigRequest_State')
CREATE NONCLUSTERED INDEX [IX_SourceConfigRequest_State] ON [KVK].[SourceConfigRequest]
(
	[RequestState] ASC,
	[RequestedUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Applied]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [FK_SourceConfigRequest_Applied] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [DesiredConfigVersionID], [AppliedPublicationID])
REFERENCES [KVK].[SourcePublication] ([SourceKey], [KVK_NO], [PeriodID], [ConfigVersionID], [PublicationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Applied]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [FK_SourceConfigRequest_Applied]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Base]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [FK_SourceConfigRequest_Base] FOREIGN KEY([SourceKey], [KVK_NO], [BaseConfigVersionID], [PeriodKey])
REFERENCES [KVK].[SourceWindowConfig] ([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Base]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [FK_SourceConfigRequest_Base]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Desired]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [FK_SourceConfigRequest_Desired] FOREIGN KEY([SourceKey], [KVK_NO], [DesiredConfigVersionID], [PeriodKey])
REFERENCES [KVK].[SourceWindowConfig] ([SourceKey], [KVK_NO], [ConfigVersionID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Desired]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [FK_SourceConfigRequest_Desired]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [FK_SourceConfigRequest_Period] FOREIGN KEY([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
REFERENCES [KVK].[SourcePeriod] ([SourceKey], [KVK_NO], [PeriodID], [PeriodKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigRequest_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [FK_SourceConfigRequest_Period]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Endpoints]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigRequest_Endpoints] CHECK  ((([OldStartScanID] IS NULL OR [OldStartScanID]>(0)) AND ([OldEndScanID] IS NULL OR [OldEndScanID]>(0)) AND ([NewStartScanID] IS NULL OR [NewStartScanID]>(0)) AND ([NewEndScanID] IS NULL OR [NewEndScanID]>(0)) AND ([OldEndScanID] IS NULL OR [OldStartScanID] IS NULL OR [OldEndScanID]>=[OldStartScanID]) AND ([NewEndScanID] IS NULL OR [NewStartScanID] IS NULL OR [NewEndScanID]>=[NewStartScanID])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Endpoints]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [CK_SourceConfigRequest_Endpoints]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigRequest_Provenance] CHECK  ((([Origin]='system' OR [Origin]='admin' OR [Origin]='authorized_import') AND datalength([Origin])=len([Origin]) AND len([Actor])>(0) AND len([Reason])>(0) AND isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [CK_SourceConfigRequest_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigRequest_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [CK_SourceConfigRequest_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigRequest_State] CHECK  ((datalength([RequestState])=len([RequestState]) AND (([RequestState]='pending' OR [RequestState]='requested') AND [AppliedPublicationID] IS NULL AND [CompletedUTC] IS NULL OR [RequestState]='applied' AND [AppliedPublicationID] IS NOT NULL AND [CompletedUTC] IS NOT NULL OR [RequestState]='rejected' AND [AppliedPublicationID] IS NULL AND [CompletedUTC] IS NOT NULL) AND ([CompletedUTC] IS NULL OR [CompletedUTC]>=[RequestedUTC])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [CK_SourceConfigRequest_State]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Versions]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigRequest_Versions] CHECK  (([BaseConfigVersionID]<>[DesiredConfigVersionID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigRequest_Versions]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigRequest]'))
ALTER TABLE [KVK].[SourceConfigRequest] CHECK CONSTRAINT [CK_SourceConfigRequest_Versions]
