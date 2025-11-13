SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Windows]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_Windows](
	[KVK_NO] [int] NOT NULL,
	[WindowName] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[WindowSeq] [tinyint] NULL,
	[StartScanID] [int] NULL,
	[EndScanID] [int] NULL,
	[Notes] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[UpdatedAtUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_KVK_Windows] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[WindowName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Windows]') AND name = N'IX_KVK_Windows_KVK')
CREATE NONCLUSTERED INDEX [IX_KVK_Windows_KVK] ON [KVK].[KVK_Windows]
(
	[KVK_NO] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Windows]') AND name = N'IX_KVK_Windows_KVK_NO_WindowName_StartScan')
CREATE NONCLUSTERED INDEX [IX_KVK_Windows_KVK_NO_WindowName_StartScan] ON [KVK].[KVK_Windows]
(
	[KVK_NO] ASC,
	[WindowName] ASC
)
WHERE ([StartScanID] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Windows]') AND name = N'IX_KVK_Windows_Scans')
CREATE NONCLUSTERED INDEX [IX_KVK_Windows_Scans] ON [KVK].[KVK_Windows]
(
	[KVK_NO] ASC,
	[StartScanID] ASC,
	[EndScanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_Windows_UpdatedAt]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Windows] ADD  CONSTRAINT [DF_Windows_UpdatedAt]  DEFAULT (sysutcdatetime()) FOR [UpdatedAtUTC]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_Windows_EndGteStart]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Windows]'))
ALTER TABLE [KVK].[KVK_Windows]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Windows_EndGteStart] CHECK  (([EndScanID] IS NULL OR [StartScanID] IS NULL OR [EndScanID]>=[StartScanID]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_Windows_EndGteStart]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Windows]'))
ALTER TABLE [KVK].[KVK_Windows] CHECK CONSTRAINT [CK_KVK_Windows_EndGteStart]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_Windows_ScanRange]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Windows]'))
ALTER TABLE [KVK].[KVK_Windows]  WITH CHECK ADD  CONSTRAINT [CK_KVK_Windows_ScanRange] CHECK  (([StartScanID] IS NULL OR [StartScanID]>=(1)))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[KVK].[CK_KVK_Windows_ScanRange]') AND parent_object_id = OBJECT_ID(N'[KVK].[KVK_Windows]'))
ALTER TABLE [KVK].[KVK_Windows] CHECK CONSTRAINT [CK_KVK_Windows_ScanRange]
