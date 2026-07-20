SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.KVKFinalReportHeader', N'U') IS NULL
BEGIN
CREATE TABLE dbo.KVKFinalReportHeader
(
    KVK_NO int NOT NULL,
    FinalDataAtUtc datetime2(0) NOT NULL,
    FinalScanOrder int NOT NULL,
    OutputRowCount int NOT NULL,
    Revision int NOT NULL,
    State nvarchar(24) COLLATE Latin1_General_CI_AS NOT NULL,
    FinalizationBasis nvarchar(24) COLLATE Latin1_General_CI_AS NOT NULL,
    CONSTRAINT PK_KVKFinalReportHeader PRIMARY KEY CLUSTERED (KVK_NO),
    CONSTRAINT CK_KVKFinalReportHeader_Values CHECK
        (KVK_NO > 0 AND FinalScanOrder > 0 AND OutputRowCount > 0 AND Revision > 0),
    CONSTRAINT CK_KVKFinalReportHeader_State CHECK (State IN (N'OUTPUT_COMPLETE')),
    CONSTRAINT CK_KVKFinalReportHeader_Basis CHECK
        (FinalizationBasis IN (N'LIVE_OUTPUT', N'AUDIT_BACKFILL', N'INFERRED_BACKFILL'))
);
END
