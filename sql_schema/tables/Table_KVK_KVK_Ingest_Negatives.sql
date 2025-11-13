SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Negatives]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_Ingest_Negatives](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[governor_id] [bigint] NOT NULL,
	[name] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[kingdom] [int] NOT NULL,
	[campid] [tinyint] NULL,
	[field_name] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[value] [bigint] NOT NULL,
	[recorded_at_utc] [datetime2](0) NOT NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Ingest_Negatives]') AND name = N'IX_KVK_Negatives')
CREATE NONCLUSTERED INDEX [IX_KVK_Negatives] ON [KVK].[KVK_Ingest_Negatives]
(
	[KVK_NO] ASC,
	[ScanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_KVK_Negatives_RecordedAt]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Ingest_Negatives] ADD  CONSTRAINT [DF_KVK_Negatives_RecordedAt]  DEFAULT (sysutcdatetime()) FOR [recorded_at_utc]
END

