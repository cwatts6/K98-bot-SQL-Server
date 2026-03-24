SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ArkTeamPreferences]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ArkTeamPreferences](
	[GovernorID] [bigint] NOT NULL,
	[PreferredTeam] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAtUTC] [datetime2](7) NOT NULL,
	[UpdatedAtUTC] [datetime2](7) NOT NULL,
	[UpdatedBy] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ArkTeamPreferences]') AND name = N'IX_ArkTeamPreferences_IsActive')
CREATE NONCLUSTERED INDEX [IX_ArkTeamPreferences_IsActive] ON [dbo].[ArkTeamPreferences]
(
	[IsActive] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_ArkTeamPreferences_IsActive]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ArkTeamPreferences] ADD  CONSTRAINT [DF_ArkTeamPreferences_IsActive]  DEFAULT ((1)) FOR [IsActive]
END

