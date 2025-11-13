SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PlayerLocation]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PlayerLocation](
	[GovernorID] [bigint] NOT NULL,
	[X] [int] NOT NULL,
	[Y] [int] NOT NULL,
	[LastUpdated] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_PlayerLocation_LastUpdated]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[PlayerLocation] ADD  CONSTRAINT [DF_PlayerLocation_LastUpdated]  DEFAULT (sysutcdatetime()) FOR [LastUpdated]
END

