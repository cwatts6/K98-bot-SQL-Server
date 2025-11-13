SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_OUTPUT_KVK_TARGETS_JUN25]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_OUTPUT_KVK_TARGETS_JUN25](
	[Rank] [bigint] NULL,
	[RANK2] [bigint] NULL,
	[Gov_ID] [float] NOT NULL,
	[Governor_Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[City Hall] [float] NULL,
	[Troops Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Tech Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Building Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Commander Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Kill Target] [int] NULL,
	[Minimum Kill Target] [int] NULL,
	[Dead Target] [int] NULL,
	[DKP Target] [int] NULL,
	[Kills Mar25 KVK] [float] NULL,
	[DEADS Mar25 KVK] [float] NULL,
	[DKP Mar25 KVK] [float] NULL,
	[% DKP Target Mar25 KVK] [float] NULL,
	[Kills Jan25 KVK] [float] NULL,
	[DEADS Jan25 KVK] [float] NULL,
	[DKP Jan25 KVK] [float] NULL,
	[% DKP Target Jan25 KVK] [float] NULL
) ON [PRIMARY]
END
