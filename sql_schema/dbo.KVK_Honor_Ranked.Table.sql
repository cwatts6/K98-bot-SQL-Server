SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Honor_Ranked]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVK_Honor_Ranked](
	[KVK_NO] [int] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[MaxHonorPoints] [bigint] NULL,
	[Honor_Rank] [bigint] NULL,
	[ScanID] [int] NULL,
	[ScanTimestampUTC] [datetime2](0) NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Honor_Ranked]') AND name = N'IX_KVKHonorRanked_KvK_Gov')
CREATE NONCLUSTERED INDEX [IX_KVKHonorRanked_KvK_Gov] ON [dbo].[KVK_Honor_Ranked]
(
	[KVK_NO] ASC,
	[GovernorID] ASC
)
INCLUDE([MaxHonorPoints],[Honor_Rank],[ScanID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
