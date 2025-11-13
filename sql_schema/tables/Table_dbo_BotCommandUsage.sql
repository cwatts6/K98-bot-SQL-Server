SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BotCommandUsage]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[BotCommandUsage](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[ExecutedAtUtc] [datetime2](3) NOT NULL,
	[CommandName] [nvarchar](64) COLLATE Latin1_General_CI_AS NOT NULL,
	[Version] [nvarchar](16) COLLATE Latin1_General_CI_AS NULL,
	[appcontext] [nvarchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[UserId] [bigint] NOT NULL,
	[UserDisplay] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[GuildId] [bigint] NULL,
	[ChannelId] [bigint] NULL,
	[Success] [bit] NOT NULL,
	[ErrorCode] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[LatencyMs] [int] NULL,
	[ArgsShape] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[ErrorText] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BotCommandUsage]') AND name = N'IX_BotCmd_AppCtx_ExecutedAt')
CREATE NONCLUSTERED INDEX [IX_BotCmd_AppCtx_ExecutedAt] ON [dbo].[BotCommandUsage]
(
	[appcontext] ASC,
	[ExecutedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BotCommandUsage]') AND name = N'IX_BotCmd_Command_ExecutedAt')
CREATE NONCLUSTERED INDEX [IX_BotCmd_Command_ExecutedAt] ON [dbo].[BotCommandUsage]
(
	[CommandName] ASC,
	[ExecutedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BotCommandUsage]') AND name = N'IX_BotCmd_ExecutedAt')
CREATE NONCLUSTERED INDEX [IX_BotCmd_ExecutedAt] ON [dbo].[BotCommandUsage]
(
	[ExecutedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[BotCommandUsage]') AND name = N'IX_BotCmd_User_ExecutedAt')
CREATE NONCLUSTERED INDEX [IX_BotCmd_User_ExecutedAt] ON [dbo].[BotCommandUsage]
(
	[UserId] ASC,
	[ExecutedAtUtc] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
