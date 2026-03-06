SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[EventInstances]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[EventInstances](
	[InstanceID] [bigint] IDENTITY(1,1) NOT NULL,
	[SourceKind] [nvarchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[SourceID] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[StartUTC] [datetime2](0) NOT NULL,
	[EndUTC] [datetime2](0) NOT NULL,
	[AllDay] [bit] NOT NULL,
	[Emoji] [nvarchar](16) COLLATE Latin1_General_CI_AS NULL,
	[Title] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
	[EventType] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Variant] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[Importance] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[Description] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[LinkURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[ChannelID] [nvarchar](32) COLLATE Latin1_General_CI_AS NULL,
	[SignupURL] [nvarchar](500) COLLATE Latin1_General_CI_AS NULL,
	[Tags] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[SortOrder] [int] NULL,
	[IsCancelled] [bit] NOT NULL,
	[GeneratedUTC] [datetime2](0) NOT NULL,
	[EffectiveHash] [varbinary](32) NULL,
 CONSTRAINT [PK_EventInstances] PRIMARY KEY CLUSTERED 
(
	[InstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[EventInstances]') AND name = N'IX_EventInstances_EventType')
CREATE NONCLUSTERED INDEX [IX_EventInstances_EventType] ON [dbo].[EventInstances]
(
	[EventType] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[EventInstances]') AND name = N'IX_EventInstances_SourceID')
CREATE NONCLUSTERED INDEX [IX_EventInstances_SourceID] ON [dbo].[EventInstances]
(
	[SourceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[EventInstances]') AND name = N'IX_EventInstances_StartUTC')
CREATE NONCLUSTERED INDEX [IX_EventInstances_StartUTC] ON [dbo].[EventInstances]
(
	[StartUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventInstances_AllDay]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventInstances] ADD  CONSTRAINT [DF_EventInstances_AllDay]  DEFAULT ((0)) FOR [AllDay]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventInstances_IsCancelled]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventInstances] ADD  CONSTRAINT [DF_EventInstances_IsCancelled]  DEFAULT ((0)) FOR [IsCancelled]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_EventInstances_GeneratedUTC]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[EventInstances] ADD  CONSTRAINT [DF_EventInstances_GeneratedUTC]  DEFAULT (sysutcdatetime()) FOR [GeneratedUTC]
END

IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventInstances_EndAfterStart]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventInstances]'))
ALTER TABLE [dbo].[EventInstances]  WITH CHECK ADD  CONSTRAINT [CK_EventInstances_EndAfterStart] CHECK  (([EndUTC]>[StartUTC]))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventInstances_EndAfterStart]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventInstances]'))
ALTER TABLE [dbo].[EventInstances] CHECK CONSTRAINT [CK_EventInstances_EndAfterStart]
IF NOT EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventInstances_SourceKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventInstances]'))
ALTER TABLE [dbo].[EventInstances]  WITH CHECK ADD  CONSTRAINT [CK_EventInstances_SourceKind] CHECK  (([SourceKind]=N'oneoff' OR [SourceKind]=N'recurring'))
IF  EXISTS (SELECT * FROM sys.check_constraints WHERE object_id = OBJECT_ID(N'[dbo].[CK_EventInstances_SourceKind]') AND parent_object_id = OBJECT_ID(N'[dbo].[EventInstances]'))
ALTER TABLE [dbo].[EventInstances] CHECK CONSTRAINT [CK_EventInstances_SourceKind]
