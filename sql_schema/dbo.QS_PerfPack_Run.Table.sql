SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[QS_PerfPack_Run]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[QS_PerfPack_Run](
	[RunId] [bigint] IDENTITY(1,1) NOT NULL,
	[RunUtc] [datetime2](0) NOT NULL,
	[LookbackDays] [int] NOT NULL,
	[Notes] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_QS_PerfPack_Run] PRIMARY KEY CLUSTERED 
(
	[RunId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_QS_PerfPack_Run_RunUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[QS_PerfPack_Run] ADD  CONSTRAINT [DF_QS_PerfPack_Run_RunUtc]  DEFAULT (sysutcdatetime()) FOR [RunUtc]
END

