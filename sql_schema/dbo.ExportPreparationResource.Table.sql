SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportPreparationResource](
	[PreparationID] [uniqueidentifier] NOT NULL,
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT [PK_ExportPreparationResource] PRIMARY KEY CLUSTERED 
(
	[PreparationID] ASC,
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]') AND name = N'IX_ExportPreparationResource_Resource')
CREATE NONCLUSTERED INDEX [IX_ExportPreparationResource_Resource] ON [dbo].[ExportPreparationResource]
(
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparationResource_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]'))
ALTER TABLE [dbo].[ExportPreparationResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportPreparationResource_Preparation] FOREIGN KEY([PreparationID])
REFERENCES [dbo].[ExportPreparation] ([PreparationID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparationResource_Preparation]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]'))
ALTER TABLE [dbo].[ExportPreparationResource] CHECK CONSTRAINT [FK_ExportPreparationResource_Preparation]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparationResource_Resource]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]'))
ALTER TABLE [dbo].[ExportPreparationResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportPreparationResource_Resource] FOREIGN KEY([ResourceKey])
REFERENCES [dbo].[ExportResource] ([ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportPreparationResource_Resource]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportPreparationResource]'))
ALTER TABLE [dbo].[ExportPreparationResource] CHECK CONSTRAINT [FK_ExportPreparationResource_Resource]
