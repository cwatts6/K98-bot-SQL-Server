SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[LogBackupTriggerQueue]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[LogBackupTriggerQueue](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[TriggerTime] [datetime2](3) NOT NULL,
	[ProcedureName] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[Reason] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Processed] [bit] NOT NULL,
	[ProcessedTime] [datetime2](3) NULL,
	[ProcessedBy] [nvarchar](128) COLLATE Latin1_General_CI_AS NULL,
	[LogUsedPctBefore] [decimal](5, 2) NULL,
	[LogUsedPctAfter] [decimal](5, 2) NULL,
	[BackupResult] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_LogBackupTriggerQueue] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[LogBackupTriggerQueue]') AND name = N'IX_LogBackupTriggerQueue_Processed')
CREATE NONCLUSTERED INDEX [IX_LogBackupTriggerQueue_Processed] ON [dbo].[LogBackupTriggerQueue]
(
	[Processed] ASC,
	[TriggerTime] DESC
)
INCLUDE([ProcedureName],[Reason],[LogUsedPctBefore]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[LogBackupTriggerQueue]') AND name = N'IX_LogBackupTriggerQueue_TriggerTime')
CREATE NONCLUSTERED INDEX [IX_LogBackupTriggerQueue_TriggerTime] ON [dbo].[LogBackupTriggerQueue]
(
	[TriggerTime] DESC
)
WHERE ([Processed]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__LogBackup__Trigg__78582794]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LogBackupTriggerQueue] ADD  DEFAULT (sysdatetime()) FOR [TriggerTime]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__LogBackup__Proce__794C4BCD]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[LogBackupTriggerQueue] ADD  DEFAULT ((0)) FOR [Processed]
END

