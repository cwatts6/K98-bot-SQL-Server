SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_ColumnInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_ColumnInventory](
	[RunId] [uniqueidentifier] NOT NULL,
	[ObjectName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ColumnId] [int] NOT NULL,
	[ColumnName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[TypeName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[MaxLength] [smallint] NOT NULL,
	[Precision] [tinyint] NOT NULL,
	[Scale] [tinyint] NOT NULL,
	[CollationName] [sysname] COLLATE Latin1_General_CI_AS NULL,
	[IsNullable] [bit] NOT NULL,
	[IsIdentity] [bit] NOT NULL,
	[IdentitySeed] [sql_variant] NULL,
	[IdentityIncrement] [sql_variant] NULL,
	[IsComputed] [bit] NOT NULL,
	[IsPersisted] [bit] NULL,
	[ComputedDefinition] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[DefaultName] [sysname] COLLATE Latin1_General_CI_AS NULL,
	[DefaultDefinition] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_KS4_Phase2_ColumnInventory] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC,
	[ObjectName] ASC,
	[ColumnId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
