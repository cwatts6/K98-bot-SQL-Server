SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KVK_Honor_Scan]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KVK_Honor_Scan](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[ScanTimestampUTC] [datetime2](0) NOT NULL,
	[SourceFileName] [nvarchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[ImportedAtUTC] [datetime2](0) NOT NULL,
	[row_count] [int] NOT NULL,
 CONSTRAINT [PK_KVK_Honor_Scan] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[ScanID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__KVK_Honor__Impor__119E3441]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[KVK_Honor_Scan] ADD  DEFAULT (sysutcdatetime()) FOR [ImportedAtUTC]
END

