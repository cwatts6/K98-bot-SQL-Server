SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[TARGETS_FEB24KVK]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[TARGETS_FEB24KVK](
	[Rank] [float] NOT NULL,
	[Gov_ID] [float] NOT NULL,
	[Governor_Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Kill Target] [int] NULL,
	[Dead Target] [int] NULL,
	[DKP Target] [int] NULL,
	[Kills_for_Last KVK] [float] NULL,
	[DEADS_for_Last KVK] [float] NULL,
	[DKP_For_Last_KVK] [float] NULL,
	[Kills_for_July KVK] [float] NULL,
	[DEADS_for_July KVK] [float] NULL,
	[DKP_For_July KVK] [float] NULL
) ON [PRIMARY]
END
