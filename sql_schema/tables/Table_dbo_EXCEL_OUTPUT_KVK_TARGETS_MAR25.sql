SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_OUTPUT_KVK_TARGETS_MAR25]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_OUTPUT_KVK_TARGETS_MAR25](
	[Rank] [float] NOT NULL,
	[RANK2] [bigint] NULL,
	[Gov_ID] [float] NOT NULL,
	[Governor_Name] [nchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Kill Target] [int] NULL,
	[Minimum Kill Target] [int] NULL,
	[Dead Target] [int] NULL,
	[DKP Target] [int] NULL,
	[Kills_for_Jan25 KVK] [float] NULL,
	[DEADS_for_Jan25 KVK] [float] NULL,
	[DKP_For_Jan25_KVK] [float] NULL,
	[% of DKP Target For Jan25 KVK] [float] NULL,
	[Kills_for_Sept24 KVK] [float] NULL,
	[DEADS_for_Sept24 KVK] [float] NULL,
	[DKP_For_Sept24_KVK] [float] NULL,
	[% of DKP Target For Sept24 KVK] [float] NULL
) ON [PRIMARY]
END
