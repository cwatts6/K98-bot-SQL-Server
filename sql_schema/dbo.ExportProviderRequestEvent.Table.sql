SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportProviderRequestEvent]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportProviderRequestEvent](
	[EventID] [uniqueidentifier] NOT NULL,
	[RequestID] [uniqueidentifier] NOT NULL,
	[EventSequence] [int] NOT NULL,
	[State] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[EvidenceHash] [binary](32) NOT NULL,
	[EvidenceReference] [uniqueidentifier] NOT NULL,
	[CreatedUTC] [datetime2](3) NOT NULL,
 CONSTRAINT [PK_ExportProviderRequestEvent] PRIMARY KEY CLUSTERED 
(
	[EventID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_ExportProviderRequestEvent_Sequence] UNIQUE NONCLUSTERED 
(
	[RequestID] ASC,
	[EventSequence] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportProviderRequestEvent_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequestEvent]'))
ALTER TABLE [dbo].[ExportProviderRequestEvent]  WITH CHECK ADD  CONSTRAINT [FK_ExportProviderRequestEvent_Request] FOREIGN KEY([RequestID])
REFERENCES [dbo].[ExportProviderRequest] ([RequestID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportProviderRequestEvent_Request]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequestEvent]'))
ALTER TABLE [dbo].[ExportProviderRequestEvent] CHECK CONSTRAINT [FK_ExportProviderRequestEvent_Request]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequestEvent_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequestEvent]'))
ALTER TABLE [dbo].[ExportProviderRequestEvent]  WITH CHECK ADD  CONSTRAINT [CK_ExportProviderRequestEvent_State] CHECK  ((datalength([State])=len([State]) AND ([EventSequence]=(1) AND [State]='prepared' OR [EventSequence]=(2) AND ([State]='not_sent' OR [State]='dispatch_intent') OR [EventSequence]=(3) AND ([State]='unknown' OR [State]='succeeded'))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_ExportProviderRequestEvent_State]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportProviderRequestEvent]'))
ALTER TABLE [dbo].[ExportProviderRequestEvent] CHECK CONSTRAINT [CK_ExportProviderRequestEvent_State]
