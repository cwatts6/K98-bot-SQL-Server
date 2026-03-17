SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_FinalResults](
	[FinalResultId] [bigint] IDENTITY(1,1) NOT NULL,
	[ImportId] [bigint] NOT NULL,
	[EventId] [bigint] NOT NULL,
	[EventMode] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[Rank] [int] NOT NULL,
	[PlayerId] [bigint] NOT NULL,
	[PlayerName] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
	[Score] [bigint] NOT NULL,
	[ReconciliationStatus] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
	[UpdatedUtc] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[FinalResultId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]') AND name = N'IX_MGE_FinalResults_EventRank')
CREATE NONCLUSTERED INDEX [IX_MGE_FinalResults_EventRank] ON [dbo].[MGE_FinalResults]
(
	[EventId] ASC,
	[Rank] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]') AND name = N'IX_MGE_FinalResults_Player')
CREATE NONCLUSTERED INDEX [IX_MGE_FinalResults_Player] ON [dbo].[MGE_FinalResults]
(
	[PlayerId] ASC,
	[EventId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__MGE_Final__Creat__4A92283B]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_FinalResults] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__MGE_Final__Updat__4B864C74]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_FinalResults] ADD  DEFAULT (sysutcdatetime()) FOR [UpdatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_FinalResults_Event]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]'))
ALTER TABLE [dbo].[MGE_FinalResults]  WITH CHECK ADD  CONSTRAINT [FK_MGE_FinalResults_Event] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_FinalResults_Event]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]'))
ALTER TABLE [dbo].[MGE_FinalResults] CHECK CONSTRAINT [FK_MGE_FinalResults_Event]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_FinalResults_Import]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]'))
ALTER TABLE [dbo].[MGE_FinalResults]  WITH CHECK ADD  CONSTRAINT [FK_MGE_FinalResults_Import] FOREIGN KEY([ImportId])
REFERENCES [dbo].[MGE_ResultImports] ([ImportId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_FinalResults_Import]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_FinalResults]'))
ALTER TABLE [dbo].[MGE_FinalResults] CHECK CONSTRAINT [FK_MGE_FinalResults_Import]
