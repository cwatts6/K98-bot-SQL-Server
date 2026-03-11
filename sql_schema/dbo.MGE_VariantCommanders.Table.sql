SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_VariantCommanders](
	[VariantCommanderId] [int] IDENTITY(1,1) NOT NULL,
	[VariantId] [int] NOT NULL,
	[CommanderId] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_VariantCommanders] PRIMARY KEY CLUSTERED 
(
	[VariantCommanderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]') AND name = N'IX_MGE_VariantCommanders_Variant')
CREATE NONCLUSTERED INDEX [IX_MGE_VariantCommanders_Variant] ON [dbo].[MGE_VariantCommanders]
(
	[VariantId] ASC,
	[IsActive] ASC
)
INCLUDE([CommanderId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]') AND name = N'UX_MGE_VariantCommanders_Pair')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_VariantCommanders_Pair] ON [dbo].[MGE_VariantCommanders]
(
	[VariantId] ASC,
	[CommanderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_VariantCommanders_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_VariantCommanders] ADD  CONSTRAINT [DF_MGE_VariantCommanders_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_VariantCommanders_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_VariantCommanders] ADD  CONSTRAINT [DF_MGE_VariantCommanders_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_VariantCommanders_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]'))
ALTER TABLE [dbo].[MGE_VariantCommanders]  WITH CHECK ADD  CONSTRAINT [FK_MGE_VariantCommanders_CommanderId] FOREIGN KEY([CommanderId])
REFERENCES [dbo].[MGE_Commanders] ([CommanderId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_VariantCommanders_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]'))
ALTER TABLE [dbo].[MGE_VariantCommanders] CHECK CONSTRAINT [FK_MGE_VariantCommanders_CommanderId]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_VariantCommanders_VariantId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]'))
ALTER TABLE [dbo].[MGE_VariantCommanders]  WITH CHECK ADD  CONSTRAINT [FK_MGE_VariantCommanders_VariantId] FOREIGN KEY([VariantId])
REFERENCES [dbo].[MGE_Variants] ([VariantId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_VariantCommanders_VariantId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_VariantCommanders]'))
ALTER TABLE [dbo].[MGE_VariantCommanders] CHECK CONSTRAINT [FK_MGE_VariantCommanders_VariantId]
