SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DeltaProcessingLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DeltaProcessingLog](
	[LogID] [int] IDENTITY(1,1) NOT NULL,
	[ExecutionTime] [datetime2](7) NULL,
	[RowsProcessed] [int] NULL,
	[LastScanProcessed] [float] NULL,
	[ElapsedMS] [int] NULL,
	[MaintenanceRan] [bit] NULL,
	[Notes] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DeltaProcessingLog]') AND name = N'IX_DeltaProcessingLog_ExecutionTime')
CREATE NONCLUSTERED INDEX [IX_DeltaProcessingLog_ExecutionTime] ON [dbo].[DeltaProcessingLog]
(
	[ExecutionTime] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__DeltaProc__Execu__1DF3C097]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DeltaProcessingLog] ADD  DEFAULT (sysutcdatetime()) FOR [ExecutionTime]
END

