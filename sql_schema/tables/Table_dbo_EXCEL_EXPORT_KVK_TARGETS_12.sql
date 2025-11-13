SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EXCEL_EXPORT_KVK_TARGETS_12]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EXCEL_EXPORT_KVK_TARGETS_12](
	[Rank] [bigint] NULL,
	[Gov_ID] [float] NOT NULL,
	[Governor_Name] [nvarchar](255) COLLATE Latin1_General_CI_AS NULL,
	[Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[City Hall] [float] NULL,
	[Troops Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Tech Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Building Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[Commander Power] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
	[BLANK1] [varchar](1) COLLATE Latin1_General_CI_AS NOT NULL,
	[Kill Target] [int] NULL,
	[Minimum Kill Target] [int] NULL,
	[Dead Target] [int] NULL,
	[DKP Target] [int] NULL,
	[BLANK2] [varchar](1) COLLATE Latin1_General_CI_AS NOT NULL,
	[Kills KVK 11] [float] NULL,
	[DEADS KVK 11] [float] NULL,
	[DKP KVK 11] [float] NULL,
	[% DKP Target KVK 11] [float] NULL,
	[BLANK3] [varchar](1) COLLATE Latin1_General_CI_AS NOT NULL,
	[Kills KVK 10] [float] NULL,
	[DEADS KVK 10] [float] NULL,
	[DKP KVK 10] [float] NULL,
	[% DKP Target KVK 10] [float] NULL
) ON [PRIMARY]
END
