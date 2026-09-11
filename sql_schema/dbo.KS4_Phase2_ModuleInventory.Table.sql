SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_ModuleInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_ModuleInventory](
	[RunId] [uniqueidentifier] NOT NULL,
	[SchemaName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ObjectName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ObjectType] [char](2) COLLATE Latin1_General_CI_AS NOT NULL,
	[DefinitionHash] [varbinary](32) NOT NULL,
	[UsesAnsiNulls] [bit] NOT NULL,
	[UsesQuotedIdentifier] [bit] NOT NULL,
 CONSTRAINT [PK_KS4_Phase2_ModuleInventory] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC,
	[SchemaName] ASC,
	[ObjectName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
