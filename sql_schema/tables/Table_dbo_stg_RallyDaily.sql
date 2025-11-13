SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[stg_RallyDaily]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[stg_RallyDaily](
	[AsOfDate] [date] NOT NULL,
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](120) COLLATE Latin1_General_CI_AS NULL,
	[TotalRallies] [int] NOT NULL,
	[RalliesLaunched] [int] NOT NULL,
	[RalliesJoined] [int] NOT NULL
) ON [PRIMARY]
END
