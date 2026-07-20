SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF OBJECT_ID(N'dbo.LeadershipPlayerReviewAudit', N'U') IS NULL
BEGIN
CREATE TABLE dbo.LeadershipPlayerReviewAudit
(
    AuditID bigint IDENTITY(1,1) NOT NULL,
    ExecutedAtUtc datetime2(3) NOT NULL,
    ActorDiscordID bigint NOT NULL,
    TargetGovernorID bigint NULL,
    GuildID bigint NOT NULL,
    ChannelID bigint NOT NULL,
    AuthorizationBasis nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
    AuthorizationRoleID bigint NULL,
    Action nvarchar(32) COLLATE Latin1_General_CI_AS NOT NULL,
    Outcome nvarchar(24) COLLATE Latin1_General_CI_AS NOT NULL,
    ErrorCode nvarchar(48) COLLATE Latin1_General_CI_AS NULL,
    RequestCorrelationID uniqueidentifier NOT NULL,
    ExpiresAtUtc datetime2(3) NOT NULL,
    CONSTRAINT PK_LeadershipPlayerReviewAudit PRIMARY KEY CLUSTERED (AuditID),
    CONSTRAINT CK_LeadershipPlayerReviewAudit_IDs CHECK
        (ActorDiscordID > 0 AND GuildID > 0 AND ChannelID > 0
         AND (TargetGovernorID IS NULL OR TargetGovernorID > 0)),
    CONSTRAINT CK_LeadershipPlayerReviewAudit_Basis CHECK
        ((AuthorizationBasis = N'LEADERSHIP_ROLE_ID'
          AND AuthorizationRoleID IS NOT NULL AND AuthorizationRoleID > 0)
         OR (AuthorizationBasis IN (N'ADMIN_USER_ID', N'NONE') AND AuthorizationRoleID IS NULL)),
    CONSTRAINT CK_LeadershipPlayerReviewAudit_Action CHECK
        (Action IN (N'open', N'ambiguity_select', N'page_change', N'period_change',
                    N'linked_governor_change', N'change_player', N'definitions', N'refresh')),
    CONSTRAINT CK_LeadershipPlayerReviewAudit_Outcome CHECK
        (Outcome IN (N'ALLOWED', N'DENIED', N'SUCCEEDED', N'FAILED',
                     N'STALE_SUPPRESSED', N'EXPIRED')),
    CONSTRAINT CK_LeadershipPlayerReviewAudit_Expiry CHECK (ExpiresAtUtc > ExecutedAtUtc)
);
END
