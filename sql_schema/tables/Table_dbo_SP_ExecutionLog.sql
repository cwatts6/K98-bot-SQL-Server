SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_ExecutionLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SP_ExecutionLog](
	[LogID] [int] IDENTITY(1,1) NOT NULL,
	[ProcedureName] [nvarchar](100) COLLATE Latin1_General_CI_AS NULL,
	[Status] [nvarchar](50) COLLATE Latin1_General_CI_AS NULL,
	[ErrorMessage] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[StartTime] [datetime] NULL,
	[EndTime] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
