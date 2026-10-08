SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceObservation]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceObservation](
	[ObservationID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ScanStartUTC] [datetime2](0) NOT NULL,
	[TimePrecision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[EventDiscriminator] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SelectedRevisionID] [uniqueidentifier] NULL,
	[SelectionVersion] [bigint] NOT NULL,
	[SupersedesObservationID] [uniqueidentifier] NULL,
 CONSTRAINT [PK_SourceObservation] PRIMARY KEY CLUSTERED 
(
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservation_Event] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ScanStartUTC] ASC,
	[TimePrecision] ASC,
	[EventDiscriminator] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceObservation_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ObservationID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservation_SelectedRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [FK_SourceObservation_SelectedRevision] FOREIGN KEY([SourceKey], [KVK_NO], [ObservationID], [SelectedRevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [ObservationID], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservation_SelectedRevision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [FK_SourceObservation_SelectedRevision]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservation_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [FK_SourceObservation_Supersedes] FOREIGN KEY([SourceKey], [KVK_NO], [SupersedesObservationID])
REFERENCES [KVK].[SourceObservation] ([SourceKey], [KVK_NO], [ObservationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceObservation_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [FK_SourceObservation_Supersedes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Event]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservation_Event] CHECK  ((len([EventDiscriminator])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Event]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [CK_SourceObservation_Event]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservation_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [CK_SourceObservation_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Selection]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservation_Selection] CHECK  (([SelectionVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Selection]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [CK_SourceObservation_Selection]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservation_Supersedes] CHECK  (([SupersedesObservationID] IS NULL OR [SupersedesObservationID]<>[ObservationID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Supersedes]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [CK_SourceObservation_Supersedes]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation]  WITH CHECK ADD  CONSTRAINT [CK_SourceObservation_Time] CHECK  ((([TimePrecision]='second' OR [TimePrecision]='minute') AND ([TimePrecision]<>'minute' OR datepart(second,[ScanStartUTC])=(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceObservation_Time]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceObservation]'))
ALTER TABLE [KVK].[SourceObservation] CHECK CONSTRAINT [CK_SourceObservation_Time]
