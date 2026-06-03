SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SqlHotfixRehearsal]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[SqlHotfixRehearsal](
	[RehearsalId] [int] IDENTITY(1,1) NOT NULL,
	[CreatedAtUtc] [datetime2](0) NOT NULL,
	[Notes] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_SqlHotfixRehearsal] PRIMARY KEY CLUSTERED 
(
	[RehearsalId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_SqlHotfixRehearsal_CreatedAtUtc]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[SqlHotfixRehearsal] ADD  CONSTRAINT [DF_SqlHotfixRehearsal_CreatedAtUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedAtUtc]
END

