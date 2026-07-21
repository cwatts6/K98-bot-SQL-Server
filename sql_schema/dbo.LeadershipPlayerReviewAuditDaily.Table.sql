SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.LeadershipPlayerReviewAuditDaily', N'U') IS NULL
BEGIN
CREATE TABLE dbo.LeadershipPlayerReviewAuditDaily
(
    AuditDateUtc date NOT NULL,
    Action nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
    Outcome nvarchar(24) COLLATE Latin1_General_CI_AS NOT NULL,
    EventCount bigint NOT NULL,
    LastAggregatedAtUtc datetime2(3) NOT NULL,
    CONSTRAINT PK_LeadershipPlayerReviewAuditDaily
        PRIMARY KEY CLUSTERED (AuditDateUtc, Action, Outcome),
    CONSTRAINT CK_LeadershipPlayerReviewAuditDaily_Count CHECK (EventCount >= 0)
);
END
