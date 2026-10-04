SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_StatisticInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_StatisticInventory](
	[RunId] [uniqueidentifier] NOT NULL,
	[ObjectName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[StatisticName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[IsAutoCreated] [bit] NOT NULL,
	[IsUserCreated] [bit] NOT NULL,
	[NoRecompute] [bit] NOT NULL,
	[HasFilter] [bit] NOT NULL,
	[FilterDefinition] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[StatisticColumns] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_KS4_Phase2_StatisticInventory] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC,
	[ObjectName] ASC,
	[StatisticName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
