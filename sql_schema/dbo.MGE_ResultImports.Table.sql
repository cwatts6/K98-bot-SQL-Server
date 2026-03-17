SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_ResultImports]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_ResultImports](
	[ImportId] [bigint] IDENTITY(1,1) NOT NULL,
	[EventId] [bigint] NOT NULL,
	[EventMode] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceType] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[Filename] [nvarchar](255) COLLATE Latin1_General_CI_AS NOT NULL,
	[FileHashSha256] [char](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[ImportStatus] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[RowCount] [int] NULL,
	[ErrorText] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
	[ActorDiscordId] [bigint] NULL,
	[DetailsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ImportId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_ResultImports]') AND name = N'IX_MGE_ResultImports_EventHash')
CREATE NONCLUSTERED INDEX [IX_MGE_ResultImports_EventHash] ON [dbo].[MGE_ResultImports]
(
	[EventId] ASC,
	[FileHashSha256] ASC,
	[ImportStatus] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_ResultImports]') AND name = N'IX_MGE_ResultImports_EventStatus')
CREATE NONCLUSTERED INDEX [IX_MGE_ResultImports_EventStatus] ON [dbo].[MGE_ResultImports]
(
	[EventId] ASC,
	[ImportStatus] ASC,
	[CreatedUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__MGE_Resul__Creat__45CD731E]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_ResultImports] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__MGE_Resul__Updat__46C19757]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_ResultImports] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_ResultImports_Event]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_ResultImports]'))
ALTER TABLE [dbo].[MGE_ResultImports]  WITH CHECK ADD  CONSTRAINT [FK_MGE_ResultImports_Event] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_ResultImports_Event]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_ResultImports]'))
ALTER TABLE [dbo].[MGE_ResultImports] CHECK CONSTRAINT [FK_MGE_ResultImports_Event]
