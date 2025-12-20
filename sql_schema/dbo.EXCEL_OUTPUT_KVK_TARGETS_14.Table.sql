SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_OUTPUT_KVK_TARGETS_14]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_OUTPUT_KVK_TARGETS_14](
	[Rank] [int] NULL,
	[RANK2] [int] NULL,
	[Gov_ID] [bigint] NULL,
	[Governor_Name] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[City Hall] [int] NULL,
	[Troops Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Tech Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Building Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Commander Power] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Kill_Target] [int] NULL,
	[Minimum_Kill_Target] [int] NULL,
	[Dead_Target] [int] NULL,
	[DKP Target] [int] NULL,
	[Kills KVK 13] [int] NULL,
	[DEADS KVK 13] [int] NULL,
	[DKP KVK 13] [int] NULL,
	[% DKP Target KVK 13] [float] NULL,
	[Kills KVK 12] [int] NULL,
	[DEADS KVK 12] [int] NULL,
	[DKP KVK 12] [int] NULL,
	[% DKP Target KVK 12] [float] NULL
) ON [PRIMARY]
END
