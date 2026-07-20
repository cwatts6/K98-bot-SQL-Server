/*
MigrationId: 20260719_005_add_leadership_player_review_audit
Purpose: Add minimized 90-day identified leadership-review audit and de-identified retention aggregates
Author: cwatts
CreatedUtc: 2026-07-19
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: SELECT OBJECT_ID(N'dbo.LeadershipPlayerReviewAudit', N'U') AS ExistingAudit;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.LeadershipPlayerReviewAudit', N'U') AS AuditTable, OBJECT_ID(N'dbo.LeadershipPlayerReviewAuditDaily', N'U') AS DailyTable, OBJECT_ID(N'dbo.usp_RecordLeadershipPlayerReviewAudit', N'P') AS RecordProcedure, OBJECT_ID(N'dbo.usp_PurgeLeadershipPlayerReviewAudit', N'P') AS PurgeProcedure;
RelatedBotPR:
RelatedSQLPR:
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
        AuthorizationBasis nvarchar(32) NOT NULL,
        AuthorizationRoleID bigint NULL,
        Action nvarchar(32) NOT NULL,
        Outcome nvarchar(24) NOT NULL,
        ErrorCode nvarchar(48) NULL,
        RequestCorrelationID uniqueidentifier NOT NULL,
        ExpiresAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_LeadershipPlayerReviewAudit PRIMARY KEY CLUSTERED (AuditID),
        CONSTRAINT CK_LeadershipPlayerReviewAudit_IDs CHECK
            (ActorDiscordID > 0 AND GuildID > 0 AND ChannelID > 0
             AND (TargetGovernorID IS NULL OR TargetGovernorID > 0)),
        CONSTRAINT CK_LeadershipPlayerReviewAudit_Basis CHECK
        (
            (AuthorizationBasis = N'LEADERSHIP_ROLE_ID'
             AND AuthorizationRoleID IS NOT NULL AND AuthorizationRoleID > 0)
            OR (AuthorizationBasis IN (N'ADMIN_USER_ID', N'NONE') AND AuthorizationRoleID IS NULL)
        ),
        CONSTRAINT CK_LeadershipPlayerReviewAudit_Action CHECK
            (Action IN
                (N'open', N'ambiguity_select', N'page_change', N'period_change',
                 N'linked_governor_change', N'change_player', N'definitions', N'refresh')),
        CONSTRAINT CK_LeadershipPlayerReviewAudit_Outcome CHECK
            (Outcome IN
                (N'ALLOWED', N'DENIED', N'SUCCEEDED', N'FAILED',
                 N'STALE_SUPPRESSED', N'EXPIRED')),
        CONSTRAINT CK_LeadershipPlayerReviewAudit_Expiry CHECK
            (ExpiresAtUtc > ExecutedAtUtc)
    );
END;
GO

IF OBJECT_ID(N'dbo.LeadershipPlayerReviewAuditDaily', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.LeadershipPlayerReviewAuditDaily
    (
        AuditDateUtc date NOT NULL,
        Action nvarchar(32) NOT NULL,
        Outcome nvarchar(24) NOT NULL,
        EventCount bigint NOT NULL,
        LastAggregatedAtUtc datetime2(3) NOT NULL,
        CONSTRAINT PK_LeadershipPlayerReviewAuditDaily
            PRIMARY KEY CLUSTERED (AuditDateUtc, Action, Outcome),
        CONSTRAINT CK_LeadershipPlayerReviewAuditDaily_Count CHECK (EventCount >= 0)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_RecordLeadershipPlayerReviewAudit
    @ActorDiscordID bigint,
    @TargetGovernorID bigint = NULL,
    @GuildID bigint,
    @ChannelID bigint,
    @AuthorizationBasis nvarchar(32),
    @AuthorizationRoleID bigint = NULL,
    @Action nvarchar(32),
    @Outcome nvarchar(24),
    @ErrorCode nvarchar(48) = NULL,
    @RequestCorrelationID uniqueidentifier,
    @ExecutedAtUtc datetime2(3) = NULL
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Executed datetime2(3) = COALESCE(@ExecutedAtUtc, SYSUTCDATETIME());

    IF @ActorDiscordID <= 0 OR @GuildID <= 0 OR @ChannelID <= 0
        THROW 51401, 'Leadership review audit requires valid actor, guild, and channel IDs.', 1;
    IF @TargetGovernorID IS NOT NULL AND @TargetGovernorID <= 0
        THROW 51402, 'Leadership review audit target Governor ID is invalid.', 1;
    IF @RequestCorrelationID IS NULL
        THROW 51403, 'Leadership review audit requires a correlation ID.', 1;
    IF @AuthorizationBasis NOT IN (N'ADMIN_USER_ID', N'LEADERSHIP_ROLE_ID', N'NONE')
        THROW 51404, 'Leadership review audit authorization basis is invalid.', 1;
    IF (@AuthorizationBasis = N'LEADERSHIP_ROLE_ID' AND ISNULL(@AuthorizationRoleID, 0) <= 0)
       OR (@AuthorizationBasis <> N'LEADERSHIP_ROLE_ID' AND @AuthorizationRoleID IS NOT NULL)
        THROW 51405, 'Leadership review audit authorization role does not match its basis.', 1;
    IF @Action NOT IN
        (N'open', N'ambiguity_select', N'page_change', N'period_change',
         N'linked_governor_change', N'change_player', N'definitions', N'refresh')
        THROW 51406, 'Leadership review audit action is invalid.', 1;
    IF @Outcome NOT IN
        (N'ALLOWED', N'DENIED', N'SUCCEEDED', N'FAILED', N'STALE_SUPPRESSED', N'EXPIRED')
        THROW 51407, 'Leadership review audit outcome is invalid.', 1;

    /* Enforce identified retention at every write; no external scheduler is required. */
    EXEC dbo.usp_PurgeLeadershipPlayerReviewAudit @NowUtc = @Executed, @EmitResult = 0;

    INSERT INTO dbo.LeadershipPlayerReviewAudit
    (
        ExecutedAtUtc, ActorDiscordID, TargetGovernorID, GuildID, ChannelID,
        AuthorizationBasis, AuthorizationRoleID, Action, Outcome, ErrorCode,
        RequestCorrelationID, ExpiresAtUtc
    )
    VALUES
    (
        @Executed, @ActorDiscordID, @TargetGovernorID, @GuildID, @ChannelID,
        @AuthorizationBasis, @AuthorizationRoleID, @Action, @Outcome,
        NULLIF(LTRIM(RTRIM(@ErrorCode)), N''), @RequestCorrelationID,
        DATEADD(DAY, 90, @Executed)
    );
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_PurgeLeadershipPlayerReviewAudit
    @NowUtc datetime2(3) = NULL,
    @EmitResult bit = 1
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @EffectiveNow datetime2(3) = COALESCE(@NowUtc, SYSUTCDATETIME());

    CREATE TABLE #ExpiredAggregate
    (
        AuditDateUtc date NOT NULL,
        Action nvarchar(32) NOT NULL,
        Outcome nvarchar(24) NOT NULL,
        EventCount bigint NOT NULL,
        PRIMARY KEY CLUSTERED (AuditDateUtc, Action, Outcome)
    );

    DECLARE @DeletedRows int;
    BEGIN TRY
        BEGIN TRANSACTION;

    INSERT INTO #ExpiredAggregate (AuditDateUtc, Action, Outcome, EventCount)
    SELECT CONVERT(date, ExecutedAtUtc), Action, Outcome, COUNT_BIG(*)
    FROM dbo.LeadershipPlayerReviewAudit WITH (UPDLOCK, HOLDLOCK)
    WHERE ExpiresAtUtc <= @EffectiveNow
    GROUP BY CONVERT(date, ExecutedAtUtc), Action, Outcome;

    UPDATE daily
    SET EventCount = daily.EventCount + expired.EventCount,
        LastAggregatedAtUtc = @EffectiveNow
    FROM dbo.LeadershipPlayerReviewAuditDaily AS daily
    JOIN #ExpiredAggregate AS expired
      ON expired.AuditDateUtc = daily.AuditDateUtc
     AND expired.Action = daily.Action
     AND expired.Outcome = daily.Outcome;

    INSERT INTO dbo.LeadershipPlayerReviewAuditDaily
        (AuditDateUtc, Action, Outcome, EventCount, LastAggregatedAtUtc)
    SELECT expired.AuditDateUtc, expired.Action, expired.Outcome,
           expired.EventCount, @EffectiveNow
    FROM #ExpiredAggregate AS expired
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.LeadershipPlayerReviewAuditDaily AS daily WITH (UPDLOCK, HOLDLOCK)
        WHERE daily.AuditDateUtc = expired.AuditDateUtc
          AND daily.Action = expired.Action
          AND daily.Outcome = expired.Outcome
    );

    DELETE FROM dbo.LeadershipPlayerReviewAudit
    WHERE ExpiresAtUtc <= @EffectiveNow;

        SET @DeletedRows = @@ROWCOUNT;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    IF @EmitResult = 1
        SELECT @DeletedRows AS DeletedIdentifiedRows,
               COALESCE((SELECT SUM(EventCount) FROM #ExpiredAggregate), 0) AS AggregatedEvents;
END;
GO
