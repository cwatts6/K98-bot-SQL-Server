SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication_Row]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVK_Target_Publication_Row](
	[PublicationId] [bigint] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[TargetRank] [bigint] NULL,
	[GovernorName] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[KillTarget] [int] NULL,
	[MinimumKillTarget] [int] NULL,
	[DeadTarget] [int] NULL,
	[DKPTarget] [int] NULL,
 CONSTRAINT [PK_KVK_Target_Publication_Row] PRIMARY KEY CLUSTERED 
(
	[PublicationId] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_KVK_Target_Publication_Row_Publication]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication_Row]'))
ALTER TABLE [dbo].[KVK_Target_Publication_Row]  WITH CHECK ADD  CONSTRAINT [FK_KVK_Target_Publication_Row_Publication] FOREIGN KEY([PublicationId])
REFERENCES [dbo].[KVK_Target_Publication] ([PublicationId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_KVK_Target_Publication_Row_Publication]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication_Row]'))
ALTER TABLE [dbo].[KVK_Target_Publication_Row] CHECK CONSTRAINT [FK_KVK_Target_Publication_Row_Publication]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_Row_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication_Row]'))
ALTER TABLE [dbo].[KVK_Target_Publication_Row]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Target_Publication_Row_Values] CHECK  (([GovernorID]>(0) AND ([KillTarget] IS NULL OR [KillTarget]>=(0)) AND ([MinimumKillTarget] IS NULL OR [MinimumKillTarget]>=(0)) AND ([DeadTarget] IS NULL OR [DeadTarget]>=(0)) AND ([DKPTarget] IS NULL OR [DKPTarget]>=(0))))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_KVK_Target_Publication_Row_Values]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Target_Publication_Row]'))
ALTER TABLE [dbo].[KVK_Target_Publication_Row] CHECK CONSTRAINT [CK_KVK_Target_Publication_Row_Values]
