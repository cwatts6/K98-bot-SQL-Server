SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_Waits]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[QS_PerfPack_Waits](
	[RunId] [bigint] NOT NULL,
	[query_id] [bigint] NOT NULL,
	[wait_category_desc] [nvarchar](60) COLLATE Latin1_General_CI_AS NOT NULL,
	[total_wait_time_ms] [bigint] NOT NULL,
	[avg_wait_time_ms] [bigint] NULL,
	[executions] [bigint] NULL,
	[query_sql_text] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_Waits]') AND name = N'IX_QS_PerfPack_Waits_Run')
CREATE NONCLUSTERED INDEX [IX_QS_PerfPack_Waits_Run] ON [dbo].[QS_PerfPack_Waits]
(
	[RunId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_QS_PerfPack_Waits_Run]') AND parent_object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_Waits]'))
ALTER TABLE [dbo].[QS_PerfPack_Waits]  WITH CHECK ADD  CONSTRAINT [FK_QS_PerfPack_Waits_Run] FOREIGN KEY([RunId])
REFERENCES [dbo].[QS_PerfPack_Run] ([RunId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_QS_PerfPack_Waits_Run]') AND parent_object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_Waits]'))
ALTER TABLE [dbo].[QS_PerfPack_Waits] CHECK CONSTRAINT [FK_QS_PerfPack_Waits_Run]
