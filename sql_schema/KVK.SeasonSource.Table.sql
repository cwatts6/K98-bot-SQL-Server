SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SeasonSource]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SeasonSource](
	[KVK_NO] [int] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChoiceID] [uniqueidentifier] NOT NULL,
	[ChosenBy] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ChosenUTC] [datetime2](0) NOT NULL,
	[Reason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NOT NULL,
	[ProvenanceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[SeasonState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[SeasonVersion] [bigint] NOT NULL,
 CONSTRAINT [PK_SeasonSource] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SeasonSource_Choice] UNIQUE NONCLUSTERED 
(
	[KVK_NO] ASC,
	[SourceKey] ASC,
	[ChoiceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource]  WITH CHECK ADD  CONSTRAINT [CK_SeasonSource_Provenance] CHECK  ((len([ChosenBy])>(0) AND len([Reason])>(0) AND isjson([ProvenanceJson])=(1) AND datalength([ProvenanceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_Provenance]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource] CHECK CONSTRAINT [CK_SeasonSource_Provenance]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource]  WITH CHECK ADD  CONSTRAINT [CK_SeasonSource_Scope] CHECK  (([KVK_NO]>(0) AND ([SourceKey]='legacy_full_data' AND datalength([SourceKey])=(16) OR [SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource] CHECK CONSTRAINT [CK_SeasonSource_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource]  WITH CHECK ADD  CONSTRAINT [CK_SeasonSource_State] CHECK  ((datalength([SeasonState])=len([SeasonState]) AND ([SeasonState]='closed' OR [SeasonState]='closing' OR [SeasonState]='open' OR [SeasonState]='planned') AND [SeasonVersion]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SeasonSource_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SeasonSource]'))
ALTER TABLE [KVK].[SeasonSource] CHECK CONSTRAINT [CK_SeasonSource_State]
