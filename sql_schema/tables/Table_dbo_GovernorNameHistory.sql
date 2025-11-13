SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[GovernorNameHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[GovernorNameHistory](
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](100) COLLATE Latin1_General_CI_AS NOT NULL,
	[FirstSeen] [datetime2](0) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[GovernorID] ASC,
	[GovernorName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_GovNameHistory_FirstSeen]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[GovernorNameHistory] ADD  CONSTRAINT [DF_GovNameHistory_FirstSeen]  DEFAULT (sysutcdatetime()) FOR [FirstSeen]
END

