SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileReceipt]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_ImportFileReceipt](
    [FileDigest] [binary](32) NOT NULL,
    [SourcePath] [nvarchar](4000) NOT NULL,
    [ArchivePath] [nvarchar](4000) NOT NULL,
    [ScanOrder] [int] NOT NULL,
    [ScanDate] [datetime] NULL,
    [RowCount] [int] NOT NULL,
    [DatabaseCommittedAtUtc] [datetime2](3) NOT NULL,
    [ArchiveStatus] [nvarchar](20) NOT NULL,
    [ArchivedAtUtc] [datetime2](3) NULL,
    [LastArchiveError] [nvarchar](2000) NULL,
 CONSTRAINT [PK_KS4_ImportFileReceipt] PRIMARY KEY CLUSTERED
(
    [FileDigest] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileReceipt_ScanOrder] UNIQUE NONCLUSTERED
(
    [ScanOrder] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [CK_KS4_ImportFileReceipt_ArchiveStatus] CHECK ([ArchiveStatus] IN (N'pending', N'archived'))
) ON [PRIMARY]
END
