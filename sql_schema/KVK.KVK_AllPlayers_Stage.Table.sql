SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[KVK].[KVK_AllPlayers_Stage]') AND type in (N'U'))
BEGIN
CREATE TABLE [KVK].[KVK_AllPlayers_Stage](
	[IngestToken] [uniqueidentifier] NOT NULL,
	[row_no] [int] IDENTITY(1,1) NOT NULL,
	[governor_id] [bigint] NOT NULL,
	[name] [nvarchar](64) COLLATE Latin1_General_CI_AS NULL,
	[kingdom] [int] NOT NULL,
	[campid] [tinyint] NULL,
	[min_points] [bigint] NULL,
	[max_points] [bigint] NULL,
	[points_difference] [bigint] NULL,
	[min_power] [bigint] NULL,
	[max_power] [bigint] NULL,
	[power_difference] [bigint] NULL,
	[first_updateUTC] [datetime2](0) NULL,
	[last_updateUTC] [datetime2](0) NULL,
	[latest_power] [bigint] NULL,
	[kill_points_diff] [bigint] NULL,
	[power_diff] [bigint] NULL,
	[dead_diff] [bigint] NULL,
	[troop_power_diff] [bigint] NULL,
	[max_units_healed_diff] [bigint] NULL,
	[healed_troops] [bigint] NULL,
	[kills_iv_diff] [bigint] NULL,
	[kills_v_diff] [bigint] NULL,
	[subscription_level] [tinyint] NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[KVK].[KVK_AllPlayers_Stage]') AND name = N'IX_KVK_AllPlayers_Stage_Token')
CREATE NONCLUSTERED INDEX [IX_KVK_AllPlayers_Stage_Token] ON [KVK].[KVK_AllPlayers_Stage]
(
	[IngestToken] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
