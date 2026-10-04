SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceRosterMember](
	[RosterID] [uniqueidentifier] NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[KVK_NO] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[b0_kingdom] [int] NOT NULL,
	[b0_power] [bigint] NULL,
 CONSTRAINT [PK_SourceRosterMember] PRIMARY KEY CLUSTERED 
(
	[RosterID] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceRosterMember_BaselineKingdom] UNIQUE NONCLUSTERED 
(
	[RosterID] ASC,
	[GovernorID] ASC,
	[b0_kingdom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRosterMember_Roster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember]  WITH CHECK ADD  CONSTRAINT [FK_SourceRosterMember_Roster] FOREIGN KEY([SourceKey], [KVK_NO], [RosterID])
REFERENCES [KVK].[SourceRoster] ([SourceKey], [KVK_NO], [RosterID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceRosterMember_Roster]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember] CHECK CONSTRAINT [FK_SourceRosterMember_Roster]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRosterMember_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember]  WITH CHECK ADD  CONSTRAINT [CK_SourceRosterMember_Identity] CHECK  (([GovernorID]>(0) AND [b0_kingdom]>(0) AND ([b0_power] IS NULL OR [b0_power]>=(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRosterMember_Identity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember] CHECK CONSTRAINT [CK_SourceRosterMember_Identity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRosterMember_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember]  WITH CHECK ADD  CONSTRAINT [CK_SourceRosterMember_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND [KVK_NO]>(0)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceRosterMember_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceRosterMember]'))
ALTER TABLE [KVK].[SourceRosterMember] CHECK CONSTRAINT [CK_SourceRosterMember_Scope]
