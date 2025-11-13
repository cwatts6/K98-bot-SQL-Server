SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RallyData_Raw]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[RallyData_Raw](
	[id] [bigint] NULL,
	[alliance_tag] [varchar](10) COLLATE Latin1_General_CI_AS NULL,
	[governor_id] [bigint] NULL,
	[governor_name] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[governor_location_x] [int] NULL,
	[governor_location_y] [int] NULL,
	[target_location_x] [int] NULL,
	[target_location_y] [int] NULL,
	[target_type] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[target_level] [int] NULL,
	[primary_commander] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[secondary_commander] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[launched] [varchar](10) COLLATE Latin1_General_CI_AS NULL,
	[cancelled] [varchar](10) COLLATE Latin1_General_CI_AS NULL,
	[start_time] [varchar](30) COLLATE Latin1_General_CI_AS NULL,
	[end_time] [varchar](30) COLLATE Latin1_General_CI_AS NULL,
	[hit_time] [bigint] NULL,
	[hit_time_pretty] [varchar](30) COLLATE Latin1_General_CI_AS NULL,
	[launch_time] [varchar](30) COLLATE Latin1_General_CI_AS NULL,
	[governors] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
