SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceRouting]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceRouting](
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[DisplayPeriodID] [uniqueidentifier] NULL,
	[Enabled] [bit] NOT NULL,
	[RoutingVersion] [bigint] NOT NULL,
	[CapabilitiesVersion] [varchar](64) COLLATE Latin1_General_100_BIN2 NULL,
	[ApprovedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NULL,
	[ApprovedUTC] [datetime2](0) NULL,
 CONSTRAINT [PK_SourceRouting] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_SourceRouting_Enabled]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[SourceRouting] ADD  CONSTRAINT [DF_SourceRouting_Enabled]  DEFAULT ((0)) FOR [Enabled]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRouting_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting]  WITH CHECK ADD  CONSTRAINT [FK_SourceRouting_Period] FOREIGN KEY([SourceKey], [KVK_NO], [DisplayPeriodID])
REFERENCES [KVK].[SourceSelection] ([SourceKey], [KVK_NO], [PeriodID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRouting_Period]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting] CHECK CONSTRAINT [FK_SourceRouting_Period]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Approval]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting]  WITH CHECK ADD  CONSTRAINT [CK_SourceRouting_Approval] CHECK  (([Enabled]=(0) OR [DisplayPeriodID] IS NOT NULL AND [CapabilitiesVersion] IS NOT NULL AND len([CapabilitiesVersion])>(0) AND [ApprovedBy] IS NOT NULL AND len([ApprovedBy])>(0) AND [ApprovedUTC] IS NOT NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Approval]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting] CHECK CONSTRAINT [CK_SourceRouting_Approval]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting]  WITH CHECK ADD  CONSTRAINT [CK_SourceRouting_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting] CHECK CONSTRAINT [CK_SourceRouting_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting]  WITH CHECK ADD  CONSTRAINT [CK_SourceRouting_Version] CHECK  (([RoutingVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRouting_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRouting]'))
ALTER TABLE [KVK].[SourceRouting] CHECK CONSTRAINT [CK_SourceRouting_Version]
