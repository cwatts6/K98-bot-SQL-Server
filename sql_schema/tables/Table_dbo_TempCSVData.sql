SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TempCSVData]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TempCSVData](
	[kingdomd] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[name] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[governor_id] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[power] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[killpoints] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[deads] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[killpoints_6month] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[kills_t1] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[kills_t2] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[kills_t3] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[kills_t4] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[kills_t5] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[helps] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[rss_gathered] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[rss_assist] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[ch25] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[date_scanned] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[account_status] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[on_map] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
