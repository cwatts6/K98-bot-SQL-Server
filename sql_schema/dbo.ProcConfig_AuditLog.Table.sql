SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ProcConfig_AuditLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ProcConfig_AuditLog](
	[AuditID] [int] IDENTITY(1,1) NOT NULL,
	[KVKVersion] [int] NULL,
	[ConfigKey] [varchar](100) COLLATE Latin1_General_CI_AS NULL,
	[OldValue] [varchar](255) COLLATE Latin1_General_CI_AS NULL,
	[NewValue] [varchar](255) COLLATE Latin1_General_CI_AS NULL,
	[OperationType] [varchar](10) COLLATE Latin1_General_CI_AS NULL,
	[ChangeDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[AuditID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF__ProcConfi__Chang__4AE49A27]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[ProcConfig_AuditLog] ADD  DEFAULT (getdate()) FOR [ChangeDate]
END

