SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Honor_AllPlayers_Raw]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVK_Honor_AllPlayers_Raw](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[HonorPoints] [bigint] NOT NULL,
 CONSTRAINT [PK_KVK_Honor_AllPlayers_Raw] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[ScanID] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_KVK_Honor_AllPlayers_Raw__Scan]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Honor_AllPlayers_Raw]'))
ALTER TABLE [dbo].[KVK_Honor_AllPlayers_Raw]  WITH CHECK ADD  CONSTRAINT [FK_KVK_Honor_AllPlayers_Raw__Scan] FOREIGN KEY([KVK_NO], [ScanID])
REFERENCES [dbo].[KVK_Honor_Scan] ([KVK_NO], [ScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_KVK_Honor_AllPlayers_Raw__Scan]') AND parent_object_id = OBJECT_ID(N'[dbo].[KVK_Honor_AllPlayers_Raw]'))
ALTER TABLE [dbo].[KVK_Honor_AllPlayers_Raw] CHECK CONSTRAINT [FK_KVK_Honor_AllPlayers_Raw__Scan]
