SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KS4_ImportFileClaim]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[KS4_ImportFileClaim](
    [CompletedFileName] [nvarchar](260) NOT NULL,
    [ReadyPath] [nvarchar](4000) NOT NULL,
    [ClaimedPath] [nvarchar](4000) NOT NULL,
    [ArchivePath] [nvarchar](4000) NOT NULL,
    [FileDigest] [binary](32) NULL,
    [ClaimStatus] [nvarchar](24) NOT NULL,
    [ClaimRequestedAtUtc] [datetime2](3) NOT NULL,
    [ClaimedAtUtc] [datetime2](3) NULL,
    [ImportCommittedAtUtc] [datetime2](3) NULL,
    [ArchivedAtUtc] [datetime2](3) NULL,
    [LastError] [nvarchar](2000) NULL,
 CONSTRAINT [PK_KS4_ImportFileClaim] PRIMARY KEY CLUSTERED
(
    [CompletedFileName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ReadyPath] UNIQUE NONCLUSTERED
(
    [ReadyPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ClaimedPath] UNIQUE NONCLUSTERED
(
    [ClaimedPath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_KS4_ImportFileClaim_ArchivePath] UNIQUE NONCLUSTERED
(
    [ArchivePath] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [CK_KS4_ImportFileClaim_Status] CHECK ([ClaimStatus] IN
    (N'claiming', N'claimed', N'imported', N'archived', N'duplicate', N'duplicate_archived', N'failed'))
) ON [PRIMARY]
END

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.KS4_ImportFileClaim')
      AND name = N'IX_KS4_ImportFileClaim_FileDigest'
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_KS4_ImportFileClaim_FileDigest]
        ON [dbo].[KS4_ImportFileClaim] ([FileDigest] ASC)
        INCLUDE ([ClaimStatus], [CompletedFileName]);
END

