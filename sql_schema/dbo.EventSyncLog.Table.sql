SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EventSyncLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EventSyncLog](
	[SyncID] [bigint] IDENTITY(1,1) NOT NULL,
	[SyncStartedUTC] [datetime2](0) NOT NULL,
	[SyncCompletedUTC] [datetime2](0) NULL,
	[SourceName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Status] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[RowsReadRecurring] [int] NULL,
	[RowsReadOneOff] [int] NULL,
	[RowsReadOverrides] [int] NULL,
	[RowsUpsertedRecurring] [int] NULL,
	[RowsUpsertedOneOff] [int] NULL,
	[RowsUpsertedOverrides] [int] NULL,
	[InstancesGenerated] [int] NULL,
	[ErrorMessage] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_EventSyncLog] PRIMARY KEY CLUSTERED 
(
	[SyncID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventSyncLog_SyncStartedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventSyncLog] ADD  CONSTRAINT [DF_EventSyncLog_SyncStartedUTC]  DEFAULT (sysutcdatetime()) FOR [SyncStartedUTC]
END

