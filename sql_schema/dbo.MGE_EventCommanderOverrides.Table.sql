SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[MGE_EventCommanderOverrides](
	[OverrideId] [int] IDENTITY(1,1) NOT NULL,
	[EventId] [bigint] NOT NULL,
	[CommanderId] [int] NOT NULL,
	[IsAdded] [bit] NOT NULL,
	[Reason] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[CreatedByDiscordId] [bigint] NULL,
	[CreatedUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_MGE_EventCommanderOverrides] PRIMARY KEY CLUSTERED 
(
	[OverrideId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]') AND name = N'UX_MGE_EventCommanderOverrides_EventCmd')
CREATE UNIQUE NONCLUSTERED INDEX [UX_MGE_EventCommanderOverrides_EventCmd] ON [dbo].[MGE_EventCommanderOverrides]
(
	[EventId] ASC,
	[CommanderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_EventCommanderOverrides_IsAdded]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_EventCommanderOverrides] ADD  CONSTRAINT [DF_MGE_EventCommanderOverrides_IsAdded]  DEFAULT ((1)) FOR [IsAdded]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_MGE_EventCommanderOverrides_CreatedUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[MGE_EventCommanderOverrides] ADD  CONSTRAINT [DF_MGE_EventCommanderOverrides_CreatedUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedUtc]
END

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_EventCmdOverrides_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]'))
ALTER TABLE [dbo].[MGE_EventCommanderOverrides]  WITH CHECK ADD  CONSTRAINT [FK_MGE_EventCmdOverrides_CommanderId] FOREIGN KEY([CommanderId])
REFERENCES [dbo].[MGE_Commanders] ([CommanderId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_EventCmdOverrides_CommanderId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]'))
ALTER TABLE [dbo].[MGE_EventCommanderOverrides] CHECK CONSTRAINT [FK_MGE_EventCmdOverrides_CommanderId]
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_EventCmdOverrides_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]'))
ALTER TABLE [dbo].[MGE_EventCommanderOverrides]  WITH CHECK ADD  CONSTRAINT [FK_MGE_EventCmdOverrides_EventId] FOREIGN KEY([EventId])
REFERENCES [dbo].[MGE_Events] ([EventId])
IF  EXISTS (SELECT * FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_MGE_EventCmdOverrides_EventId]') AND parent_object_id = OBJECT_ID(N'[dbo].[MGE_EventCommanderOverrides]'))
ALTER TABLE [dbo].[MGE_EventCommanderOverrides] CHECK CONSTRAINT [FK_MGE_EventCmdOverrides_EventId]
