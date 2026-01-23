SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Debug_SqlDiagnostics]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Debug_SqlDiagnostics](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[KVK] [int] NULL,
	[Context] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[SqlText] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[ErrorMessage] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__Debug_Sql__Creat__18650473]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Debug_SqlDiagnostics] ADD  DEFAULT (sysutcdatetime()) FOR [CreatedAt]
END

