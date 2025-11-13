SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_Player_Windowed](
	[KVK_NO] [int] NOT NULL,
	[WindowName] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[governor_id] [bigint] NOT NULL,
	[name] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[kingdom] [int] NOT NULL,
	[campid] [tinyint] NULL,
	[kp_gain] [bigint] NOT NULL,
	[kp_gain_recalc] [bigint] NOT NULL,
	[kills_gain] [bigint] NOT NULL,
	[t4_kills] [bigint] NOT NULL,
	[t5_kills] [bigint] NOT NULL,
	[kp_loss] [bigint] NOT NULL,
	[healed_troops] [bigint] NOT NULL,
	[deads] [bigint] NOT NULL,
	[starting_power] [bigint] NOT NULL,
	[dkp] [float] NOT NULL,
	[last_scan_id] [int] NOT NULL,
	[computed_at_utc] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_KVK_Player_Windowed] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[WindowName] ASC,
	[governor_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND name = N'IX_KVK_Player_Windowed_KVK_NO_governor_id')
CREATE NONCLUSTERED INDEX [IX_KVK_Player_Windowed_KVK_NO_governor_id] ON [KVK].[KVK_Player_Windowed]
(
	[KVK_NO] ASC,
	[governor_id] ASC
)
INCLUDE([kingdom],[starting_power]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND name = N'IX_KVK_Player_Windowed_KVK_NO_Kingdom')
CREATE NONCLUSTERED INDEX [IX_KVK_Player_Windowed_KVK_NO_Kingdom] ON [KVK].[KVK_Player_Windowed]
(
	[KVK_NO] ASC,
	[kingdom] ASC
)
INCLUDE([governor_id],[starting_power]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND name = N'IX_KVK_Player_Windowed_KVK_NO_WindowName')
CREATE NONCLUSTERED INDEX [IX_KVK_Player_Windowed_KVK_NO_WindowName] ON [KVK].[KVK_Player_Windowed]
(
	[KVK_NO] ASC,
	[WindowName] ASC
)
INCLUDE([governor_id],[name],[kingdom],[campid],[t4_kills],[t5_kills],[deads],[starting_power]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND name = N'IX_PlayerWin_Camp')
CREATE NONCLUSTERED INDEX [IX_PlayerWin_Camp] ON [KVK].[KVK_Player_Windowed]
(
	[KVK_NO] ASC,
	[WindowName] ASC,
	[campid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Player_Windowed]') AND name = N'IX_PlayerWin_Kingdom')
CREATE NONCLUSTERED INDEX [IX_PlayerWin_Kingdom] ON [KVK].[KVK_Player_Windowed]
(
	[KVK_NO] ASC,
	[WindowName] ASC,
	[kingdom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_PlayerWin_At]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Player_Windowed] ADD  CONSTRAINT [DF_PlayerWin_At]  DEFAULT (sysutcdatetime()) FOR [computed_at_utc]
END

