SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceCampReportRow](
	[RevisionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[CampID] [tinyint] NOT NULL,
	[CampLabel] [nvarchar](256) COLLATE Latin1_General_CI_AS NOT NULL,
	[MappingDigest] [binary](32) NOT NULL,
	[t4_kills] [decimal](38, 6) NOT NULL,
	[t4_kills_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[t4_kills_unit] [decimal](38, 6) NOT NULL,
	[t4_kills_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[t5_kills] [decimal](38, 6) NOT NULL,
	[t5_kills_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[t5_kills_unit] [decimal](38, 6) NOT NULL,
	[t5_kills_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[kp_t4_t5] [decimal](38, 6) NOT NULL,
	[kp_t4_t5_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[kp_t4_t5_unit] [decimal](38, 6) NOT NULL,
	[kp_t4_t5_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[dead] [decimal](38, 6) NOT NULL,
	[dead_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[dead_unit] [decimal](38, 6) NOT NULL,
	[dead_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[t4_t5_dead] [decimal](38, 6) NOT NULL,
	[t4_t5_dead_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[t4_t5_dead_unit] [decimal](38, 6) NOT NULL,
	[t4_t5_dead_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[healed] [decimal](38, 6) NOT NULL,
	[healed_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[healed_unit] [decimal](38, 6) NOT NULL,
	[healed_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[acclaim] [decimal](38, 6) NOT NULL,
	[acclaim_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[acclaim_unit] [decimal](38, 6) NOT NULL,
	[acclaim_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[dkp] [decimal](38, 6) NOT NULL,
	[dkp_raw] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[dkp_unit] [decimal](38, 6) NOT NULL,
	[dkp_precision] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RawCellsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceCampReportRow] PRIMARY KEY CLUSTERED 
(
	[RevisionID] ASC,
	[CampID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCampReportRow_Revision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [FK_SourceCampReportRow_Revision] FOREIGN KEY([SourceKey], [KVK_NO], [RevisionID], [MappingDigest])
REFERENCES [KVK].[SourceAggregateRevision] ([SourceKey], [KVK_NO], [RevisionID], [MappingDigest])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceCampReportRow_Revision]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [FK_SourceCampReportRow_Revision]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_acclaim] CHECK  (([acclaim]>=(0) AND [acclaim_unit]>(0) AND len([acclaim_raw])>(0) AND ([acclaim_precision]='reported_abbreviated' OR [acclaim_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_acclaim]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_acclaim]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_dead] CHECK  (([dead]>=(0) AND [dead_unit]>(0) AND len([dead_raw])>(0) AND ([dead_precision]='reported_abbreviated' OR [dead_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_dkp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_dkp] CHECK  (([dkp]>=(0) AND [dkp_unit]>(0) AND len([dkp_raw])>(0) AND ([dkp_precision]='reported_abbreviated' OR [dkp_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_dkp]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_dkp]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_healed] CHECK  (([healed]>=(0) AND [healed_unit]>(0) AND len([healed_raw])>(0) AND ([healed_precision]='reported_abbreviated' OR [healed_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_healed]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_healed]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_Identity] CHECK  (([CampID]>=(1) AND [CampID]<=(8) AND len([CampLabel])>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_kp_t4_t5]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_kp_t4_t5] CHECK  (([kp_t4_t5]>=(0) AND [kp_t4_t5_unit]>(0) AND len([kp_t4_t5_raw])>(0) AND ([kp_t4_t5_precision]='reported_abbreviated' OR [kp_t4_t5_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_kp_t4_t5]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_kp_t4_t5]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Raw]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_Raw] CHECK  ((isjson([RawCellsJson])=(1) AND datalength([RawCellsJson])<=(1048576)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Raw]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_Raw]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_t4_kills] CHECK  (([t4_kills]>=(0) AND [t4_kills_unit]>(0) AND len([t4_kills_raw])>(0) AND ([t4_kills_precision]='reported_abbreviated' OR [t4_kills_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t4_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_t4_kills]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t4_t5_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_t4_t5_dead] CHECK  (([t4_t5_dead]>=(0) AND [t4_t5_dead_unit]>(0) AND len([t4_t5_dead_raw])>(0) AND ([t4_t5_dead_precision]='reported_abbreviated' OR [t4_t5_dead_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t4_t5_dead]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_t4_t5_dead]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow]  WITH CHECK ADD  CONSTRAINT [CK_SourceCampReportRow_t5_kills] CHECK  (([t5_kills]>=(0) AND [t5_kills_unit]>(0) AND len([t5_kills_raw])>(0) AND ([t5_kills_precision]='reported_abbreviated' OR [t5_kills_precision]='reported_numeric')))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceCampReportRow_t5_kills]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceCampReportRow]'))
ALTER TABLE [KVK].[SourceCampReportRow] CHECK CONSTRAINT [CK_SourceCampReportRow_t5_kills]
