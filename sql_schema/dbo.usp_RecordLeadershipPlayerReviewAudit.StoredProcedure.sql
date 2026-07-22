SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_RecordLeadershipPlayerReviewAudit]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[usp_RecordLeadershipPlayerReviewAudit] AS' 
END
ALTER PROCEDURE [dbo].[usp_RecordLeadershipPlayerReviewAudit]
	@ActorDiscordID [bigint],
	@TargetGovernorID [bigint] = NULL,
	@GuildID [bigint],
	@ChannelID [bigint],
	@AuthorizationBasis [nvarchar](32),
	@AuthorizationRoleID [bigint] = NULL,
	@Action [nvarchar](32),
	@Outcome [nvarchar](24),
	@ErrorCode [nvarchar](48) = NULL,
	@RequestCorrelationID [uniqueidentifier],
	@ExecutedAtUtc [datetime2](3) = NULL
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

