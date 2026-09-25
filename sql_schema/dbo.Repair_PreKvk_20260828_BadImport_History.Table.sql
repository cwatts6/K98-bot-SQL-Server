SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Repair_PreKvk_20260828_BadImport_History]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Repair_PreKvk_20260828_BadImport_History](
	[HistoryID] [bigint] NOT NULL,
	[KVK_NO] [int] NULL,
	[Filename] [nvarchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileHashSha256] [char](64) COLLATE Latin1_General_CI_AS NULL,
	[HashPrefix] [char](8) COLLATE Latin1_General_CI_AS NULL,
	[ImportStatus] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[Phase] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[RowCount] [int] NULL,
	[ScanID] [int] NULL,
	[ErrorType] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[ErrorText] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[UploaderDiscordID] [bigint] NULL,
	[ChannelID] [bigint] NULL,
	[MessageID] [bigint] NULL,
	[CreatedUTC] [datetime2](7) NOT NULL
) ON [PRIMARY]
END
