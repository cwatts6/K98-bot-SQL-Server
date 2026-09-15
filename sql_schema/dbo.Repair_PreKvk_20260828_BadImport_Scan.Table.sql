SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repair_PreKvk_20260828_BadImport_Scan]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Repair_PreKvk_20260828_BadImport_Scan](
	[KVK_NO] [int] NOT NULL,
	[ScanID] [int] NOT NULL,
	[ScanTimestampUTC] [datetime2](0) NOT NULL,
	[SourceFileName] [nvarchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileHash] [varbinary](32) NULL,
	[row_count] [int] NULL,
	[ImportedAtUTC] [datetime2](0) NOT NULL
) ON [PRIMARY]
END
