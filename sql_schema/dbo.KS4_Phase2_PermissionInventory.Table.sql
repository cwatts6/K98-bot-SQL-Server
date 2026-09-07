SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_PermissionInventory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_PermissionInventory](
	[RunId] [uniqueidentifier] NOT NULL,
	[ObjectName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[PrincipalName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[StateCode] [char](1) COLLATE Latin1_General_CI_AS NOT NULL,
	[PermissionName] [sysname] COLLATE Latin1_General_CI_AS NOT NULL,
	[ColumnId] [int] NOT NULL,
 CONSTRAINT [PK_KS4_Phase2_PermissionInventory] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC,
	[ObjectName] ASC,
	[PrincipalName] ASC,
	[PermissionName] ASC,
	[ColumnId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
