SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Variants]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_Variants](
	[VariantId] [int] IDENTITY(1,1) NOT NULL,
	[VariantName] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL,
	[IsActive] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_Variants] PRIMARY KEY CLUSTERED 
(
	[VariantId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_Variants]') AND name = N'UX_MGE_Variants_Name')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_Variants_Name] ON [dbo].[MGE_Variants]
(
	[VariantName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Variants_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Variants] ADD  CONSTRAINT [DF_MGE_Variants_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Variants_SortOrder]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Variants] ADD  CONSTRAINT [DF_MGE_Variants_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Variants_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Variants] ADD  CONSTRAINT [DF_MGE_Variants_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_Variants_UpdatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_Variants] ADD  CONSTRAINT [DF_MGE_Variants_UpdatedUtc]  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

