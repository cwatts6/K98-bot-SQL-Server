SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorSessionLocks]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorSessionLocks](
	[LockScope] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL,
	[GovernorID] [nvarchar](50) COLLATE Latin1_General_CI_AS NOT NULL,
	[HolderDiscordUserID] [bigint] NOT NULL,
	[ExpiresAtUTC] [datetime2](0) NOT NULL,
	[CreatedAtUTC] [datetime2](0) NOT NULL,
	[UpdatedAtUTC] [datetime2](0) NOT NULL,
 CONSTRAINT [PK_GovernorSessionLocks] PRIMARY KEY CLUSTERED 
(
	[LockScope] ASC,
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[GovernorSessionLocks]') AND name = N'IX_GovernorSessionLocks_ExpiresAtUTC')
CREATE NONCLUSTERED INDEX [IX_GovernorSessionLocks_ExpiresAtUTC] ON [dbo].[GovernorSessionLocks]
(
	[ExpiresAtUTC] ASC
)
INCLUDE([LockScope],[GovernorID],[HolderDiscordUserID]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
