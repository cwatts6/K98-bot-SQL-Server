SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.KVK_Target_Publication', N'U') IS NULL
BEGIN
CREATE TABLE dbo.KVK_Target_Publication
(
    PublicationId bigint IDENTITY(1, 1) NOT NULL,
    KVK_NO int NOT NULL,
    PublicationState nvarchar(16) COLLATE Latin1_General_CI_AS NOT NULL,
    SourceScanOrder int NOT NULL,
    SourceScanType nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
    ConfiguredDraftScan int NULL,
    ConfiguredMatchmakingScan int NULL,
    PublishedAtUtc datetime2(3) NOT NULL,
    TargetRowCount int NOT NULL,
    OutputObjectName nvarchar(257) COLLATE Latin1_General_CI_AS NOT NULL,
    PublicationVersion int NOT NULL,
    PublicationSignature uniqueidentifier NOT NULL,
    IsCurrent bit NOT NULL,
    ForcedRepublish bit NOT NULL,
    RepublishReason nvarchar(400) COLLATE Latin1_General_CI_AS NULL,
    PublishedBy nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL,
    CONSTRAINT PK_KVK_Target_Publication
        PRIMARY KEY CLUSTERED (PublicationId),
    CONSTRAINT UQ_KVK_Target_Publication_KVK_Version
        UNIQUE (KVK_NO, PublicationVersion),
    CONSTRAINT UQ_KVK_Target_Publication_Signature
        UNIQUE (PublicationSignature),
    CONSTRAINT CK_KVK_Target_Publication_Values
        CHECK
        (
            KVK_NO > 0
            AND SourceScanOrder > 0
            AND TargetRowCount > 0
            AND PublicationVersion > 0
            AND (ConfiguredDraftScan IS NULL OR ConfiguredDraftScan > 0)
            AND (ConfiguredMatchmakingScan IS NULL OR ConfiguredMatchmakingScan > 0)
        ),
    CONSTRAINT CK_KVK_Target_Publication_StateSource
        CHECK
        (
            (
                PublicationState = N'DRAFT'
                AND SourceScanType = N'DRAFTSCAN'
                AND ConfiguredDraftScan IS NOT NULL
                AND SourceScanOrder <= ConfiguredDraftScan
            )
            OR
            (
                PublicationState = N'OFFICIAL'
                AND SourceScanType = N'MATCHMAKING_SCAN'
                AND ConfiguredMatchmakingScan IS NOT NULL
                AND SourceScanOrder = ConfiguredMatchmakingScan
            )
        ),
    CONSTRAINT CK_KVK_Target_Publication_RepublishAudit
        CHECK
        (
            (ForcedRepublish = 0 AND RepublishReason IS NULL)
            OR
            (ForcedRepublish = 1 AND NULLIF(LTRIM(RTRIM(RepublishReason)), N'') IS NOT NULL)
        ),
    CONSTRAINT CK_KVK_Target_Publication_OutputObject
        CHECK
        (
            OutputObjectName =
                N'dbo.EXCEL_EXPORT_KVK_TARGETS_' + CONVERT(nvarchar(20), KVK_NO)
        )
);

CREATE UNIQUE NONCLUSTERED INDEX UX_KVK_Target_Publication_Current
    ON dbo.KVK_Target_Publication (KVK_NO)
    WHERE IsCurrent = 1;
END
