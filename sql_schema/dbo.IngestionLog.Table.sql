SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IngestionLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IngestionLog](
	[IngestionID] [bigint] IDENTITY(1,1) NOT NULL,
	[Source] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileName] [nvarchar](260) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileHash] [varchar](64) COLLATE Latin1_General_CI_AS NULL,
	[AsOfDate] [date] NULL,
	[RowsIn] [int] NOT NULL,
	[StartedAt] [datetime2](0) NOT NULL,
	[EndedAt] [datetime2](0) NULL,
	[Status] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[ErrorMessage] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[IngestionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Source] ASC,
	[FileName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__Ingestion__Start__26E107E5]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[IngestionLog] ADD  DEFAULT (sysutcdatetime()) FOR [StartedAt]
END

