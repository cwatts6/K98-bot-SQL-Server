SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PlayerLocation_Staging]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PlayerLocation_Staging](
	[player_id] [bigint] NOT NULL,
	[player_name] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[player_power] [bigint] NULL,
	[player_kills] [bigint] NULL,
	[player_ch] [int] NULL,
	[player_alliance] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[x] [int] NOT NULL,
	[y] [int] NOT NULL,
	[ImportedAt] [datetime2](0) NOT NULL
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerLoc_Stg_ImportedAt]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerLocation_Staging] ADD  CONSTRAINT [DF_PlayerLoc_Stg_ImportedAt]  DEFAULT (sysutcdatetime()) FOR [ImportedAt]
END

