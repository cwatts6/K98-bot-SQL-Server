SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_TopQueries]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[QS_PerfPack_TopQueries](
	[RunId] [bigint] NOT NULL,
	[Metric] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL,
	[query_id] [bigint] NOT NULL,
	[plan_count] [int] NOT NULL,
	[executions] [bigint] NOT NULL,
	[avg_duration_us] [bigint] NULL,
	[avg_cpu_us] [bigint] NULL,
	[avg_logical_reads] [bigint] NULL,
	[total_duration_us] [bigint] NULL,
	[total_cpu_us] [bigint] NULL,
	[total_logical_reads] [bigint] NULL,
	[query_sql_text] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_TopQueries]') AND name = N'IX_QS_PerfPack_TopQueries_RunMetric')
CREATE NONCLUSTERED INDEX [IX_QS_PerfPack_TopQueries_RunMetric] ON [dbo].[QS_PerfPack_TopQueries]
(
	[RunId] ASC,
	[Metric] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_QS_PerfPack_TopQueries_Run]') AND parent_object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_TopQueries]'))
ALTER TABLE [dbo].[QS_PerfPack_TopQueries]  WITH CHECK ADD  CONSTRAINT [FK_QS_PerfPack_TopQueries_Run] FOREIGN KEY([RunId])
REFERENCES [dbo].[QS_PerfPack_Run] ([RunId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_QS_PerfPack_TopQueries_Run]') AND parent_object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_TopQueries]'))
ALTER TABLE [dbo].[QS_PerfPack_TopQueries] CHECK CONSTRAINT [FK_QS_PerfPack_TopQueries_Run]
