SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceRoster]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceRoster](
	[RosterID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[RosterVersion] [int] NOT NULL,
	[B0RevisionID] [uniqueidentifier] NOT NULL,
	[ScopeDigest] [binary](32) NOT NULL,
	[MemberDigest] [binary](32) NOT NULL,
	[MemberCount] [int] NOT NULL,
	[ApprovedUTC] [datetime2](0) NOT NULL,
	[ApprovedBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceRoster] PRIMARY KEY CLUSTERED 
(
	[RosterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceRoster_Scope] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[RosterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceRoster_Version] UNIQUE NONCLUSTERED 
(
	[SourceKey] ASC,
	[KVK_NO] ASC,
	[RosterVersion] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRoster_B0]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster]  WITH CHECK ADD  CONSTRAINT [FK_SourceRoster_B0] FOREIGN KEY([SourceKey], [KVK_NO], [B0RevisionID])
REFERENCES [KVK].[SourceObservationRevision] ([SourceKey], [KVK_NO], [RevisionID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRoster_B0]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster] CHECK CONSTRAINT [FK_SourceRoster_B0]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster]  WITH CHECK ADD  CONSTRAINT [CK_SourceRoster_Provenance] CHECK  ((len([ApprovedBy])>(0) AND len([Reason])>(0) AND isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster] CHECK CONSTRAINT [CK_SourceRoster_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster]  WITH CHECK ADD  CONSTRAINT [CK_SourceRoster_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster] CHECK CONSTRAINT [CK_SourceRoster_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster]  WITH CHECK ADD  CONSTRAINT [CK_SourceRoster_Version] CHECK  (([RosterVersion]>(0) AND [MemberCount]>(0) AND [MemberCount]<=(50000)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRoster_Version]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRoster]'))
ALTER TABLE [KVK].[SourceRoster] CHECK CONSTRAINT [CK_SourceRoster_Version]
