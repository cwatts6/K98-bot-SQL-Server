SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DiscordServerActivityEvents]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[DiscordServerActivityEvents](
	[ActivityEventId] [bigint] IDENTITY(1,1) NOT NULL,
	[OccurredAtUtc] [datetime2](0) NOT NULL,
	[GuildId] [bigint] NOT NULL,
	[ChannelId] [bigint] NULL,
	[UserId] [bigint] NOT NULL,
	[EventType] [nvarchar](32) COLLATE Latin1_General_CI_AS NOT NULL,
	[MetadataJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_DiscordServerActivityEvents] PRIMARY KEY CLUSTERED 
(
	[ActivityEventId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[DiscordServerActivityEvents]') AND name = N'IX_DiscordServerActivityEvents_Window')
CREATE NONCLUSTERED INDEX [IX_DiscordServerActivityEvents_Window] ON [dbo].[DiscordServerActivityEvents]
(
	[OccurredAtUtc] ASC,
	[GuildId] ASC,
	[UserId] ASC,
	[EventType] ASC
)
INCLUDE([ChannelId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_DiscordServerActivityEvents_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[DiscordServerActivityEvents] ADD  CONSTRAINT [DF_DiscordServerActivityEvents_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

