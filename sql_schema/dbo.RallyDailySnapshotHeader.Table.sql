SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.RallyDailySnapshotHeader', N'U') IS NULL
BEGIN
CREATE TABLE dbo.RallyDailySnapshotHeader
(
    AsOfDate date NOT NULL,
    CompletedAtUtc datetime2(0) NOT NULL,
    SourceRowCount int NOT NULL,
    DistinctGovernorCount int NOT NULL,
    Revision int NOT NULL,
    CompletionBasis nvarchar(24) COLLATE Latin1_General_CI_AS NOT NULL,
    ImportBatchID bigint NULL,
    CONSTRAINT PK_RallyDailySnapshotHeader PRIMARY KEY CLUSTERED (AsOfDate),
    CONSTRAINT CK_RallyDailySnapshotHeader_Counts CHECK
        (SourceRowCount >= 0 AND DistinctGovernorCount >= 0
         AND DistinctGovernorCount <= SourceRowCount),
    CONSTRAINT CK_RallyDailySnapshotHeader_Revision CHECK (Revision > 0),
    CONSTRAINT CK_RallyDailySnapshotHeader_Basis CHECK
        (CompletionBasis IN
            (N'LIVE_IMPORT', N'AUDIT_BACKFILL', N'OTHER_AUTHORITY', N'INFERRED_DATE'))
);
END
