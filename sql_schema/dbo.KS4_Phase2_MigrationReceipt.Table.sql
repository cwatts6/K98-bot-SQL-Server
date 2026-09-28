SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_Phase2_MigrationReceipt]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_Phase2_MigrationReceipt](
	[ReceiptId] [bigint] IDENTITY(1,1) NOT NULL,
	[RunId] [uniqueidentifier] NOT NULL,
	[Direction] [varchar](16) COLLATE Latin1_General_CI_AS NOT NULL,
	[StepName] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
	[StartedAtUtc] [datetime2](7) NOT NULL,
	[FinishedAtUtc] [datetime2](7) NOT NULL,
	[DurationMs] [decimal](19, 3) NOT NULL,
	[RowsAffected] [bigint] NULL,
	[Notes] [nvarchar](1000) COLLATE Latin1_General_CI_AS NULL,
 CONSTRAINT [PK_KS4_Phase2_MigrationReceipt] PRIMARY KEY CLUSTERED 
(
	[ReceiptId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END
