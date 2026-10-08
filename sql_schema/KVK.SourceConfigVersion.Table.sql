SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceConfigVersion](
	[ConfigVersionID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[ConfigVersion] [int] NOT NULL,
	[RosterID] [uniqueidentifier] NOT NULL,
	[ConfigContentHash] [binary](32) NOT NULL,
	[WindowDigest] [binary](32) NOT NULL,
	[MappingDigest] [binary](32) NOT NULL,
	[WeightDigest] [binary](32) NOT NULL,
	[ApprovedUTC] [datetime2](0) NOT NULL,
	[ApprovedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceConfigVersion] PRIMARY KEY CLUSTERED 
(
	[ConfigVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceConfigVersion_Roster] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ConfigVersionID] ASC,
	[RosterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceConfigVersion_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ConfigVersionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceConfigVersion_Version] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[ConfigVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigVersion_Roster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion]  WITH CHECK ADD  CONSTRAINT [FK_SourceConfigVersion_Roster] FOREIGN KEY([SourceKey], [KVK_NO], [RosterID])
REFERENCES [KVK].[SourceRoster] ([SourceKey], [KVK_NO], [RosterID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceConfigVersion_Roster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion] CHECK CONSTRAINT [FK_SourceConfigVersion_Roster]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigVersion_Provenance] CHECK  ((len([ApprovedBy])>(0) AND len([Reason])>(0) AND isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion] CHECK CONSTRAINT [CK_SourceConfigVersion_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigVersion_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion] CHECK CONSTRAINT [CK_SourceConfigVersion_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion]  WITH CHECK ADD  CONSTRAINT [CK_SourceConfigVersion_Version] CHECK  (([ConfigVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceConfigVersion_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceConfigVersion]'))
ALTER TABLE [KVK].[SourceConfigVersion] CHECK CONSTRAINT [CK_SourceConfigVersion_Version]
