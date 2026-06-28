SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[FallbackImportBatchControl]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[FallbackImportBatchControl](
	[ControlId] [bigint] IDENTITY(1,1) NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[SourceType] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceFilename] [nvarchar](260) COLLATE Latin1_General_CI_AS NULL,
	[ScoreHeader] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[ColumnsPresentJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[RowsInSource] [int] NULL,
	[RowsWritten] [int] NULL,
 CONSTRAINT [PK_FallbackImportBatchControl] PRIMARY KEY CLUSTERED 
(
	[ControlId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_FallbackImportBatchControl_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[FallbackImportBatchControl] ADD  CONSTRAINT [DF_FallbackImportBatchControl_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

