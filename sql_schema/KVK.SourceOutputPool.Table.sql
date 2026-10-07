SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[SourceOutputPool](
	[PoolID] [uniqueidentifier] NOT NULL,
	[IndexFileID] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[IndexFileKind] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[RegistrationNo] [int] NOT NULL,
	[AccountKey] [varchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AccountResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ExpectedOwner] [nvarchar](128) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[AudienceJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceKey] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[ActiveKVK] [int] NULL,
	[ChoiceID] [uniqueidentifier] NULL,
	[Epoch] [bigint] NOT NULL,
	[PoolState] [varchar](32) COLLATE Latin1_General_100_BIN2 NOT NULL,
	[OwnerID] [uniqueidentifier] NULL,
	[Fence] [bigint] NOT NULL,
	[Version] [bigint] NOT NULL,
	[BlockedReason] [nvarchar](1024) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUTC] [datetime2](0) NOT NULL,
	[UpdatedUTC] [datetime2](0) NOT NULL,
	[RegistrationHash] [binary](32) NOT NULL,
	[RegistrationJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_SourceOutputPool] PRIMARY KEY CLUSTERED 
(
	[PoolID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputPool_Account] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[AccountKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputPool_File] UNIQUE NONCLUSTERED 
(
	[PoolID] ASC,
	[IndexFileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputPool_Index] UNIQUE NONCLUSTERED 
(
	[IndexFileID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_SourceOutputPool_Registration] UNIQUE NONCLUSTERED 
(
	[RegistrationNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]') AND name = N'IX_SourceOutputPool_State')
CREATE NONCLUSTERED INDEX [IX_SourceOutputPool_State] ON [KVK].[SourceOutputPool]
(
	[AccountKey] ASC,
	[PoolState] ASC,
	[PoolID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Account]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputPool_Account] FOREIGN KEY([AccountResourceKey])
REFERENCES [dbo].[ExportResource] ([ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Account]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [FK_SourceOutputPool_Account]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputPool_Choice] FOREIGN KEY([ActiveKVK], [SourceKey], [ChoiceID])
REFERENCES [KVK].[SeasonSource] ([KVK_NO], [SourceKey], [ChoiceID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Choice]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [FK_SourceOutputPool_Choice]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [FK_SourceOutputPool_Index] FOREIGN KEY([IndexFileID], [IndexFileKind])
REFERENCES [KVK].[SourceOutputFile] ([FileID], [FileKind])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[KVK].[FK_SourceOutputPool_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [FK_SourceOutputPool_Index]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Account]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Account] CHECK  ((len([AccountKey])>(0) AND NOT [AccountKey] like ('%[^A-Za-z0-9_.@:-]%') collate Latin1_General_100_BIN2 AND [AccountResourceKey]=('account:'+[AccountKey]) AND datalength([AccountResourceKey])=((8)+datalength([AccountKey]))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Account]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Account]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Audience]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Audience] CHECK  ((isjson([AudienceJson])=(1) AND datalength([AudienceJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Audience]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Audience]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Blocked]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Blocked] CHECK  (([PoolState]='blocked' AND [BlockedReason] IS NOT NULL AND len([BlockedReason])>(0) OR [PoolState]<>'blocked' AND [BlockedReason] IS NULL))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Blocked]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Blocked]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Counters] CHECK  (([Epoch]>(0) AND [Version]>(0) AND [UpdatedUTC]>=[CreatedUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Counters]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Counters]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Evidence] CHECK  ((isjson([RegistrationJson])=(1) AND datalength([RegistrationJson])<=(65536)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Evidence]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Evidence]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Index] CHECK  (([IndexFileKind]='index' AND datalength([IndexFileKind])=(5)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Index]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Index]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_OwnerIdentity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_OwnerIdentity] CHECK  ((len([ExpectedOwner])>(0) AND datalength([ExpectedOwner])=datalength(ltrim(rtrim([ExpectedOwner])))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_OwnerIdentity]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_OwnerIdentity]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Ownership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Ownership] CHECK  (([OwnerID] IS NULL AND [Fence]>=(0) AND [PoolState]<>'closing' OR [OwnerID] IS NOT NULL AND [Fence]>(0) AND [PoolState]<>'closed'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Ownership]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Ownership]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Registration]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Registration] CHECK  (([RegistrationNo]>=(1) AND [RegistrationNo]<=(8)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Registration]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Registration]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_Scope] CHECK  (([SourceKey]='snapshot_report_v1' AND datalength([SourceKey])=(18) AND ([ActiveKVK] IS NULL AND [ChoiceID] IS NULL AND ([PoolState]='blocked' OR [PoolState]='setup') OR [ActiveKVK] IS NOT NULL AND [ActiveKVK]>(0) AND [ChoiceID] IS NOT NULL)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_Scope]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_Scope]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool]  WITH CHECK ADD  CONSTRAINT [CK_SourceOutputPool_State] CHECK  ((([PoolState]='blocked' OR [PoolState]='setup' OR [PoolState]='closed' OR [PoolState]='closing' OR [PoolState]='active') AND datalength([PoolState])=len([PoolState])))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_SourceOutputPool_State]') AND parent_object_id = OBJECT_ID(N'[KVK].[SourceOutputPool]'))
ALTER TABLE [KVK].[SourceOutputPool] CHECK CONSTRAINT [CK_SourceOutputPool_State]
