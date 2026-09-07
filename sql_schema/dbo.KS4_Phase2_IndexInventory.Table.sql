SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_IndexInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_IndexInventory](
	[RunId] [uniqueidentifier] NOT NULL,
	[ObjectName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[IndexName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[TypeDesc] [nvarchar](60) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsUnique] [bit] NOT NULL,
	[IsPrimaryKey] [bit] NOT NULL,
	[IsDisabled] [bit] NOT NULL,
	[HasFilter] [bit] NOT NULL,
	[FilterDefinition] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[KeyColumns] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
	[IncludeColumns] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_KS4_Phase2_IndexInventory] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC,
	[ObjectName] ASC,
	[IndexName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
