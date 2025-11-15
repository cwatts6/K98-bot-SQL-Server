SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ErrorAudit]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ErrorAudit](
	[ErrorTime] [datetime2](7) NULL,
	[ProcedureName] [nvarchar](200) COLLATE Latin1_General_CI_AS NULL,
	[ErrorNumber] [int] NULL,
	[ErrorMessage] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
	[ErrorLine] [int] NULL,
	[AdditionalInfo] [nvarchar](4000) COLLATE Latin1_General_CI_AS NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
