SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[PlayerAccountStatus_StagingCSV]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[PlayerAccountStatus_StagingCSV](
	[GovernorID] [bigint] NOT NULL,
	[GovernorName] [nvarchar](400) COLLATE Latin1_General_CI_AS NULL,
	[Status] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[UpdatedAtRaw] [nvarchar](40) COLLATE Latin1_General_CI_AS NULL,
	[AccountType] [nvarchar](10) COLLATE Latin1_General_CI_AS NULL,
	[Main_GovernorID_Raw] [nvarchar](40) COLLATE Latin1_General_CI_AS NULL,
	[Role] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Extra1] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Extra2] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Extra3] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Extra4] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY]
END
