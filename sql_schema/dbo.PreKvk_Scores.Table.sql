SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PreKvk_Scores]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PreKvk_Scores](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Points] [int] NOT NULL,
 CONSTRAINT [PK_PreKvk_Scores] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[ScanID] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[PreKvk_Scores]') AND name = N'IX_PreKvk_Scores_KVK_Scan_Gov')
CREATE NONCLUSTERED INDEX [IX_PreKvk_Scores_KVK_Scan_Gov] ON [dbo].[PreKvk_Scores]
(
	[KVK_NO] ASC,
	[ScanID] ASC,
	[GovernorID] ASC
)
INCLUDE([Points],[GovernorName]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_PreKvk_Scores_Scan]') AND parent_object_id = OBJECT_ID(N'[dbo].[PreKvk_Scores]'))
ALTER TABLE [dbo].[PreKvk_Scores]  WITH CHECK ADD  CONSTRAINT [FK_PreKvk_Scores_Scan] FOREIGN KEY([KVK_NO], [ScanID])
REFERENCES [dbo].[PreKvk_Scan] ([KVK_NO], [ScanID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_PreKvk_Scores_Scan]') AND parent_object_id = OBJECT_ID(N'[dbo].[PreKvk_Scores]'))
ALTER TABLE [dbo].[PreKvk_Scores] CHECK CONSTRAINT [FK_PreKvk_Scores_Scan]
