SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_OUTPUT_CURRENT_KVK_TARGETS_NEW_SEPT24]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_OUTPUT_CURRENT_KVK_TARGETS_NEW_SEPT24](
	[Rank] [float] NOT NULL,
	[RANK2] [bigint] NULL,
	[Gov_ID] [float] NOT NULL,
	[Governor_Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Kill Target] [int] NULL,
	[Dead Target] [int] NULL,
	[DKP Target] [int] NULL,
	[Kills_for_Last KVK] [float] NULL,
	[DEADS_for_Last KVK] [float] NULL,
	[DKP_For_Last_KVK] [float] NULL,
	[% of DKP Target For Last KVK] [float] NULL,
	[Kills_for_OCT KVK] [float] NULL,
	[DEADS_for_OCT KVK] [float] NULL,
	[DKP_For_OCT KVK] [float] NULL,
	[% of DKP Target For OCT KVK] [float] NULL
) ON [PRIMARY]
END
