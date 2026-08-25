SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.KVK_Target_Publication_Row', N'U') IS NULL
BEGIN
CREATE TABLE dbo.KVK_Target_Publication_Row
(
    PublicationId bigint NOT NULL,
    GovernorID bigint NOT NULL,
    TargetRank bigint NULL,
    GovernorName nvarchar(255) COLLATE Latin1_General_CI_AS NULL,
    Power nvarchar(4000) COLLATE Latin1_General_CI_AS NULL,
    KillTarget int NULL,
    MinimumKillTarget int NULL,
    DeadTarget int NULL,
    DKPTarget int NULL,
    CONSTRAINT PK_KVK_Target_Publication_Row
        PRIMARY KEY CLUSTERED (PublicationId, GovernorID),
    CONSTRAINT FK_KVK_Target_Publication_Row_Publication
        FOREIGN KEY (PublicationId)
        REFERENCES dbo.KVK_Target_Publication (PublicationId),
    CONSTRAINT CK_KVK_Target_Publication_Row_Values
        CHECK
        (
            GovernorID > 0
            AND (KillTarget IS NULL OR KillTarget >= 0)
            AND (MinimumKillTarget IS NULL OR MinimumKillTarget >= 0)
            AND (DeadTarget IS NULL OR DeadTarget >= 0)
            AND (DKPTarget IS NULL OR DKPTarget >= 0)
        )
);
END
