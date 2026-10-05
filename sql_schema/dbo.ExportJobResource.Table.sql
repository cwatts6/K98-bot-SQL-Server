SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ExportJobResource]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ExportJobResource](
	[JobID] [uniqueidentifier] NOT NULL,
	[ResourceKey] [varchar](256) COLLATE Latin1_General_100_BIN2 NOT NULL,
 CONSTRAINT [PK_ExportJobResource] PRIMARY KEY CLUSTERED 
(
	[JobID] ASC,
	[ResourceKey] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ExportJobResource]') AND name = N'IX_ExportJobResource_Resource')
CREATE NONCLUSTERED INDEX [IX_ExportJobResource_Resource] ON [dbo].[ExportJobResource]
(
	[ResourceKey] ASC,
	[JobID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJobResource_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJobResource]'))
ALTER TABLE [dbo].[ExportJobResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportJobResource_Job] FOREIGN KEY([JobID])
REFERENCES [dbo].[ExportJob] ([JobID])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJobResource_Job]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJobResource]'))
ALTER TABLE [dbo].[ExportJobResource] CHECK CONSTRAINT [FK_ExportJobResource_Job]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJobResource_Resource]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJobResource]'))
ALTER TABLE [dbo].[ExportJobResource]  WITH CHECK ADD  CONSTRAINT [FK_ExportJobResource_Resource] FOREIGN KEY([ResourceKey])
REFERENCES [dbo].[ExportResource] ([ResourceKey])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_ExportJobResource_Resource]') AND parent_object_id = OBJECT_ID(N'[dbo].[ExportJobResource]'))
ALTER TABLE [dbo].[ExportJobResource] CHECK CONSTRAINT [FK_ExportJobResource_Resource]
