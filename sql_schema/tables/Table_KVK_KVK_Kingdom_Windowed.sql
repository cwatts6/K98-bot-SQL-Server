SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Kingdom_Windowed]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_Kingdom_Windowed](
	[KVK_NO] [int] NOT NULL,
	[WindowName] [nvarchar](40) COLLATE Latin1_General_CI_AS NOT NULL,
	[kingdom] [int] NOT NULL,
	[kp_gain] [bigint] NOT NULL,
	[kills_gain] [bigint] NOT NULL,
	[t4_kills] [bigint] NOT NULL,
	[t5_kills] [bigint] NOT NULL,
	[kp_loss] [bigint] NOT NULL,
	[healed_troops] [bigint] NOT NULL,
	[deads] [bigint] NOT NULL,
	[dkp] [float] NOT NULL,
	[last_scan_id] [int] NOT NULL,
	[computed_at_utc] [datetime2](0) NOT NULL,
	[campid] [int] NOT NULL,
	[camp_name] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
 CONSTRAINT [PK_KVK_Kingdom_Windowed] PRIMARY KEY CLUSTERED 
(
	[KVK_NO] ASC,
	[WindowName] ASC,
	[kingdom] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Kingdom_Windowed]') AND name = N'IX_KingWin_KVK')
CREATE NONCLUSTERED INDEX [IX_KingWin_KVK] ON [KVK].[KVK_Kingdom_Windowed]
(
	[KVK_NO] ASC,
	[WindowName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
SET ANSI_PADDING ON

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_Kingdom_Windowed]') AND name = N'IX_KVK_Kingdom_Windowed_KVK_NO_WindowName')
CREATE NONCLUSTERED INDEX [IX_KVK_Kingdom_Windowed_KVK_NO_WindowName] ON [KVK].[KVK_Kingdom_Windowed]
(
	[KVK_NO] ASC,
	[WindowName] ASC
)
INCLUDE([kingdom],[t4_kills],[t5_kills],[deads]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_KingWin_At]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Kingdom_Windowed] ADD  CONSTRAINT [DF_KingWin_At]  DEFAULT (sysutcdatetime()) FOR [computed_at_utc]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_KingdomWin_campid]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Kingdom_Windowed] ADD  CONSTRAINT [DF_KingdomWin_campid]  DEFAULT ((0)) FOR [campid]
END

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[DF_KingdomWin_campname]') AND type = 'D')
BEGIN
ALTER TABLE [KVK].[KVK_Kingdom_Windowed] ADD  CONSTRAINT [DF_KingdomWin_campname]  DEFAULT (N'') FOR [camp_name]
END

