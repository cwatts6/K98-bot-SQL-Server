/*
MigrationId: 20260709_001_add_vote_survey_admin_delete
Purpose: Add SQL-admin vote/survey hard-delete procedure with durable deletion audit
Author: cwatts
CreatedUtc: 2026-07-09
RequiresBackup: Yes
RiskLevel: High
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: N/A until manual procedure execution
PreValidationQuery: SELECT OBJECT_ID(N'dbo.VotePosts', N'U') AS VotePostsObjectId, OBJECT_ID(N'dbo.SurveyPosts', N'U') AS SurveyPostsObjectId;
PostValidationQuery: SELECT OBJECT_ID(N'dbo.VoteSurveyDeletionAudit', N'U') AS DeletionAuditObjectId, OBJECT_ID(N'dbo.usp_VoteSurveyAdminDelete', N'P') AS DeleteProcObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
This migration only creates an audit table and manual SQL-admin stored procedure. It does not
delete data during deployment. Destructive deletion happens only when a SQL admin executes
dbo.usp_VoteSurveyAdminDelete with @DryRun = 0, @ConfirmDelete = 1, a closed vote/survey ID, and a
non-empty reason.

Execution safety:
- Dry-run is the default and returns item metadata plus dependent row counts.
- Open vote/survey items are rejected.
- A durable audit/readback row is inserted outside the deleted item tree before hard delete.
- Deletes run in one transaction with XACT_ABORT ON and dependency-order statements.
- Public Discord messages are intentionally outside this SQL procedure.

Recovery note:
The procedure performs hard deletes. After a confirmed delete, recovery requires restore from a
database backup or an operator-prepared pre-delete data script. This migration intentionally does
not provide a reverse/rebuild procedure.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[VoteSurveyDeletionAudit](
        [DeletionAuditID] [bigint] IDENTITY(1,1) NOT NULL,
        [ContentKind] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [ContentID] [bigint] NOT NULL,
        [Title] [nvarchar](200) COLLATE Latin1_General_CI_AS NOT NULL,
        [Status] [varchar](20) COLLATE Latin1_General_CI_AS NOT NULL,
        [GuildID] [bigint] NOT NULL,
        [ChannelID] [bigint] NOT NULL,
        [MessageID] [bigint] NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [ClosesAtUtc] [datetime2](0) NOT NULL,
        [ClosedAtUtc] [datetime2](0) NULL,
        [DeletedAtUtc] [datetime2](0) NOT NULL,
        [DeletedBy] [nvarchar](128) COLLATE Latin1_General_CI_AS NOT NULL,
        [Reason] [nvarchar](500) COLLATE Latin1_General_CI_AS NOT NULL,
        [BreakGlassProductionDelete] [bit] NOT NULL,
        [RowCountsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
        [LocalAuditSummaryJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NULL,
        CONSTRAINT [PK_VoteSurveyDeletionAudit] PRIMARY KEY CLUSTERED ([DeletionAuditID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VoteSurveyDeletionAudit_DeletedAtUtc')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] ADD CONSTRAINT [DF_VoteSurveyDeletionAudit_DeletedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [DeletedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_ContentKind')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_ContentKind] CHECK ([ContentKind] IN ('Vote', 'Survey'));
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_Reason')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_Reason] CHECK (LEN(LTRIM(RTRIM([Reason]))) BETWEEN 1 AND 500);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_DeletedBy')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_DeletedBy] CHECK (LEN(LTRIM(RTRIM([DeletedBy]))) BETWEEN 1 AND 128);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_RowCountsJson')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_RowCountsJson] CHECK (ISJSON([RowCountsJson]) = 1);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson')
    ALTER TABLE [dbo].[VoteSurveyDeletionAudit] WITH CHECK ADD CONSTRAINT [CK_VoteSurveyDeletionAudit_LocalAuditSummaryJson] CHECK ([LocalAuditSummaryJson] IS NULL OR ISJSON([LocalAuditSummaryJson]) = 1);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[dbo].[VoteSurveyDeletionAudit]')
      AND name = N'IX_VoteSurveyDeletionAudit_Content'
)
    CREATE NONCLUSTERED INDEX [IX_VoteSurveyDeletionAudit_Content]
    ON [dbo].[VoteSurveyDeletionAudit]([ContentKind], [ContentID], [DeletedAtUtc]);
GO

CREATE OR ALTER PROCEDURE [dbo].[usp_VoteSurveyAdminDelete]
    @ContentKind [varchar](20),
    @VotePostID [bigint] = NULL,
    @SurveyID [bigint] = NULL,
    @DryRun [bit] = 1,
    @ConfirmDelete [bit] = 0,
    @Reason [nvarchar](500) = NULL,
    @DeletedBy [nvarchar](128) = NULL,
    @BreakGlassProductionDelete [bit] = 0
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @DryRun = ISNULL(@DryRun, 1);
    SET @ConfirmDelete = ISNULL(@ConfirmDelete, 0);
    SET @BreakGlassProductionDelete = ISNULL(@BreakGlassProductionDelete, 0);

    DECLARE @NormalizedContentKind varchar(20) = UPPER(LTRIM(RTRIM(ISNULL(@ContentKind, ''))));
    DECLARE @ReasonTrimmed nvarchar(500) = NULLIF(LTRIM(RTRIM(ISNULL(@Reason, N''))), N'');
    DECLARE @DeletedByTrimmed nvarchar(128) = NULLIF(LTRIM(RTRIM(ISNULL(@DeletedBy, N''))), N'');
    DECLARE @ContentID bigint;
    DECLARE @Title nvarchar(200);
    DECLARE @Status varchar(20);
    DECLARE @GuildID bigint;
    DECLARE @ChannelID bigint;
    DECLARE @MessageID bigint;
    DECLARE @CreatedAtUtc datetime2(0);
    DECLARE @ClosesAtUtc datetime2(0);
    DECLARE @ClosedAtUtc datetime2(0);
    DECLARE @RowCountsJson nvarchar(max);
    DECLARE @LocalAuditSummaryJson nvarchar(max);

    IF @NormalizedContentKind NOT IN ('VOTE', 'SURVEY')
        THROW 51000, 'ContentKind must be Vote or Survey.', 1;

    IF @NormalizedContentKind = 'VOTE' AND (@VotePostID IS NULL OR @SurveyID IS NOT NULL)
        THROW 51001, 'Vote deletion requires VotePostID and no SurveyID.', 1;

    IF @NormalizedContentKind = 'SURVEY' AND (@SurveyID IS NULL OR @VotePostID IS NOT NULL)
        THROW 51002, 'Survey deletion requires SurveyID and no VotePostID.', 1;

    IF @ReasonTrimmed IS NULL
        THROW 51003, 'Reason is required.', 1;

    IF @DeletedByTrimmed IS NULL
        THROW 51004, 'DeletedBy is required.', 1;

    IF @DryRun = 0 AND @ConfirmDelete <> 1
        THROW 51005, 'Confirmed delete requires ConfirmDelete = 1.', 1;

    IF @NormalizedContentKind = 'VOTE'
    BEGIN
        SELECT
            @ContentID = NULL,
            @Title = NULL,
            @Status = NULL,
            @GuildID = NULL,
            @ChannelID = NULL,
            @MessageID = NULL,
            @CreatedAtUtc = NULL,
            @ClosesAtUtc = NULL,
            @ClosedAtUtc = NULL;

        SELECT
            @ContentID = p.VotePostID,
            @Title = p.Title,
            @Status = p.Status,
            @GuildID = p.GuildID,
            @ChannelID = p.ChannelID,
            @MessageID = p.MessageID,
            @CreatedAtUtc = p.CreatedAtUtc,
            @ClosesAtUtc = p.ClosesAtUtc,
            @ClosedAtUtc = p.ClosedAtUtc
        FROM dbo.VotePosts p
        WHERE p.VotePostID = @VotePostID;

        IF @ContentID IS NULL
            THROW 51006, 'VotePostID was not found.', 1;

        IF @Status <> 'Closed'
            THROW 51007, 'Vote must be closed before deletion.', 1;

        SELECT @RowCountsJson = (
            SELECT
                (SELECT COUNT_BIG(1) FROM dbo.VotePosts WHERE VotePostID = @VotePostID) AS VotePosts,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostOptions WHERE VotePostID = @VotePostID) AS VotePostOptions,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostVotes WHERE VotePostID = @VotePostID) AS VotePostVotes,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectVotes WHERE VotePostID = @VotePostID) AS VotePostMultiSelectVotes,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectSelections WHERE VotePostID = @VotePostID) AS VotePostMultiSelectSelections,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostReminders WHERE VotePostID = @VotePostID) AS VotePostReminders,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostAudit WHERE VotePostID = @VotePostID) AS VotePostAudit
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @LocalAuditSummaryJson = (
            SELECT
                COUNT_BIG(1) AS AuditRowCount,
                MIN(CreatedAtUtc) AS FirstAuditAtUtc,
                MAX(CreatedAtUtc) AS LastAuditAtUtc,
                JSON_QUERY((
                    SELECT ActionType, COUNT_BIG(1) AS RowCount
                    FROM dbo.VotePostAudit
                    WHERE VotePostID = @VotePostID
                    GROUP BY ActionType
                    FOR JSON PATH
                )) AS ActionCounts
            FROM dbo.VotePostAudit
            WHERE VotePostID = @VotePostID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END;
    ELSE
    BEGIN
        SELECT
            @ContentID = NULL,
            @Title = NULL,
            @Status = NULL,
            @GuildID = NULL,
            @ChannelID = NULL,
            @MessageID = NULL,
            @CreatedAtUtc = NULL,
            @ClosesAtUtc = NULL,
            @ClosedAtUtc = NULL;

        SELECT
            @ContentID = p.SurveyID,
            @Title = p.Title,
            @Status = p.Status,
            @GuildID = p.GuildID,
            @ChannelID = p.ChannelID,
            @MessageID = p.MessageID,
            @CreatedAtUtc = p.CreatedAtUtc,
            @ClosesAtUtc = p.ClosesAtUtc,
            @ClosedAtUtc = p.ClosedAtUtc
        FROM dbo.SurveyPosts p
        WHERE p.SurveyID = @SurveyID;

        IF @ContentID IS NULL
            THROW 51008, 'SurveyID was not found.', 1;

        IF @Status <> 'Closed'
            THROW 51009, 'Survey must be closed before deletion.', 1;

        SELECT @RowCountsJson = (
            SELECT
                (SELECT COUNT_BIG(1) FROM dbo.SurveyPosts WHERE SurveyID = @SurveyID) AS SurveyPosts,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyQuestions WHERE SurveyID = @SurveyID) AS SurveyQuestions,
                (SELECT COUNT_BIG(1)
                 FROM dbo.SurveyQuestionOptions o
                 JOIN dbo.SurveyQuestions q ON q.SurveyQuestionID = o.SurveyQuestionID
                 WHERE q.SurveyID = @SurveyID) AS SurveyQuestionOptions,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyResponses WHERE SurveyID = @SurveyID) AS SurveyResponses,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswers WHERE SurveyID = @SurveyID) AS SurveyAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyTextAnswers WHERE SurveyID = @SurveyID) AS SurveyTextAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswerDetails WHERE SurveyID = @SurveyID) AS SurveyAnswerDetails,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingAnswers WHERE SurveyID = @SurveyID) AS SurveyRatingAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRankingAnswers WHERE SurveyID = @SurveyID) AS SurveyRankingAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingChoiceLabels WHERE SurveyID = @SurveyID) AS SurveyRatingChoiceLabels,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyResponseDrafts WHERE SurveyID = @SurveyID) AS SurveyResponseDrafts,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyReminders WHERE SurveyID = @SurveyID) AS SurveyReminders,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAudit WHERE SurveyID = @SurveyID) AS SurveyAudit
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @LocalAuditSummaryJson = (
            SELECT
                COUNT_BIG(1) AS AuditRowCount,
                MIN(CreatedAtUtc) AS FirstAuditAtUtc,
                MAX(CreatedAtUtc) AS LastAuditAtUtc,
                JSON_QUERY((
                    SELECT ActionType, COUNT_BIG(1) AS RowCount
                    FROM dbo.SurveyAudit
                    WHERE SurveyID = @SurveyID
                    GROUP BY ActionType
                    FOR JSON PATH
                )) AS ActionCounts
            FROM dbo.SurveyAudit
            WHERE SurveyID = @SurveyID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END;

    SELECT
        CASE WHEN @NormalizedContentKind = 'VOTE' THEN 'Vote' ELSE 'Survey' END AS ContentKind,
        @ContentID AS ContentID,
        @Title AS Title,
        @Status AS Status,
        @GuildID AS GuildID,
        @ChannelID AS ChannelID,
        @MessageID AS MessageID,
        @CreatedAtUtc AS CreatedAtUtc,
        @ClosesAtUtc AS ClosesAtUtc,
        @ClosedAtUtc AS ClosedAtUtc,
        CAST(@DryRun AS bit) AS DryRun,
        CAST(@BreakGlassProductionDelete AS bit) AS BreakGlassProductionDelete,
        @ReasonTrimmed AS Reason,
        @DeletedByTrimmed AS DeletedBy;

    SELECT [key] AS RowName, TRY_CONVERT(bigint, [value]) AS RowCount
    FROM OPENJSON(@RowCountsJson)
    ORDER BY [key];

    SELECT @LocalAuditSummaryJson AS LocalAuditSummaryJson;

    IF @DryRun = 1
        RETURN 0;

    BEGIN TRANSACTION;

    IF @NormalizedContentKind = 'VOTE'
    BEGIN
        SELECT
            @ContentID = p.VotePostID,
            @Title = p.Title,
            @Status = p.Status,
            @GuildID = p.GuildID,
            @ChannelID = p.ChannelID,
            @MessageID = p.MessageID,
            @CreatedAtUtc = p.CreatedAtUtc,
            @ClosesAtUtc = p.ClosesAtUtc,
            @ClosedAtUtc = p.ClosedAtUtc
        FROM dbo.VotePosts p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.VotePostID = @VotePostID;

        IF @ContentID IS NULL
            THROW 51010, 'VotePostID was not found during confirmed delete.', 1;

        IF @Status <> 'Closed'
            THROW 51011, 'Vote must remain closed during confirmed delete.', 1;

        SELECT @RowCountsJson = (
            SELECT
                (SELECT COUNT_BIG(1) FROM dbo.VotePosts WHERE VotePostID = @VotePostID) AS VotePosts,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostOptions WHERE VotePostID = @VotePostID) AS VotePostOptions,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostVotes WHERE VotePostID = @VotePostID) AS VotePostVotes,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectVotes WHERE VotePostID = @VotePostID) AS VotePostMultiSelectVotes,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectSelections WHERE VotePostID = @VotePostID) AS VotePostMultiSelectSelections,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostReminders WHERE VotePostID = @VotePostID) AS VotePostReminders,
                (SELECT COUNT_BIG(1) FROM dbo.VotePostAudit WHERE VotePostID = @VotePostID) AS VotePostAudit
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @LocalAuditSummaryJson = (
            SELECT
                COUNT_BIG(1) AS AuditRowCount,
                MIN(CreatedAtUtc) AS FirstAuditAtUtc,
                MAX(CreatedAtUtc) AS LastAuditAtUtc,
                JSON_QUERY((
                    SELECT ActionType, COUNT_BIG(1) AS RowCount
                    FROM dbo.VotePostAudit
                    WHERE VotePostID = @VotePostID
                    GROUP BY ActionType
                    FOR JSON PATH
                )) AS ActionCounts
            FROM dbo.VotePostAudit
            WHERE VotePostID = @VotePostID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END;
    ELSE
    BEGIN
        SELECT
            @ContentID = p.SurveyID,
            @Title = p.Title,
            @Status = p.Status,
            @GuildID = p.GuildID,
            @ChannelID = p.ChannelID,
            @MessageID = p.MessageID,
            @CreatedAtUtc = p.CreatedAtUtc,
            @ClosesAtUtc = p.ClosesAtUtc,
            @ClosedAtUtc = p.ClosedAtUtc
        FROM dbo.SurveyPosts p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.SurveyID = @SurveyID;

        IF @ContentID IS NULL
            THROW 51012, 'SurveyID was not found during confirmed delete.', 1;

        IF @Status <> 'Closed'
            THROW 51013, 'Survey must remain closed during confirmed delete.', 1;

        SELECT @RowCountsJson = (
            SELECT
                (SELECT COUNT_BIG(1) FROM dbo.SurveyPosts WHERE SurveyID = @SurveyID) AS SurveyPosts,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyQuestions WHERE SurveyID = @SurveyID) AS SurveyQuestions,
                (SELECT COUNT_BIG(1)
                 FROM dbo.SurveyQuestionOptions o
                 JOIN dbo.SurveyQuestions q ON q.SurveyQuestionID = o.SurveyQuestionID
                 WHERE q.SurveyID = @SurveyID) AS SurveyQuestionOptions,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyResponses WHERE SurveyID = @SurveyID) AS SurveyResponses,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswers WHERE SurveyID = @SurveyID) AS SurveyAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyTextAnswers WHERE SurveyID = @SurveyID) AS SurveyTextAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswerDetails WHERE SurveyID = @SurveyID) AS SurveyAnswerDetails,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingAnswers WHERE SurveyID = @SurveyID) AS SurveyRatingAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRankingAnswers WHERE SurveyID = @SurveyID) AS SurveyRankingAnswers,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingChoiceLabels WHERE SurveyID = @SurveyID) AS SurveyRatingChoiceLabels,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyResponseDrafts WHERE SurveyID = @SurveyID) AS SurveyResponseDrafts,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyReminders WHERE SurveyID = @SurveyID) AS SurveyReminders,
                (SELECT COUNT_BIG(1) FROM dbo.SurveyAudit WHERE SurveyID = @SurveyID) AS SurveyAudit
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        SELECT @LocalAuditSummaryJson = (
            SELECT
                COUNT_BIG(1) AS AuditRowCount,
                MIN(CreatedAtUtc) AS FirstAuditAtUtc,
                MAX(CreatedAtUtc) AS LastAuditAtUtc,
                JSON_QUERY((
                    SELECT ActionType, COUNT_BIG(1) AS RowCount
                    FROM dbo.SurveyAudit
                    WHERE SurveyID = @SurveyID
                    GROUP BY ActionType
                    FOR JSON PATH
                )) AS ActionCounts
            FROM dbo.SurveyAudit
            WHERE SurveyID = @SurveyID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
    END;

    INSERT INTO dbo.VoteSurveyDeletionAudit
        (
            ContentKind, ContentID, Title, Status, GuildID, ChannelID, MessageID,
            CreatedAtUtc, ClosesAtUtc, ClosedAtUtc, DeletedAtUtc, DeletedBy, Reason,
            BreakGlassProductionDelete, RowCountsJson, LocalAuditSummaryJson
        )
    VALUES
        (
            CASE WHEN @NormalizedContentKind = 'VOTE' THEN 'Vote' ELSE 'Survey' END,
            @ContentID, @Title, @Status, @GuildID, @ChannelID, @MessageID,
            @CreatedAtUtc, @ClosesAtUtc, @ClosedAtUtc, SYSUTCDATETIME(), @DeletedByTrimmed,
            @ReasonTrimmed, @BreakGlassProductionDelete, @RowCountsJson, @LocalAuditSummaryJson
        );

    IF @NormalizedContentKind = 'VOTE'
    BEGIN
        DELETE FROM dbo.VotePostMultiSelectSelections WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePostMultiSelectVotes WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePostVotes WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePostReminders WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePostAudit WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePostOptions WHERE VotePostID = @VotePostID;
        DELETE FROM dbo.VotePosts WHERE VotePostID = @VotePostID;
    END;
    ELSE
    BEGIN
        DELETE FROM dbo.SurveyAnswerDetails WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyTextAnswers WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyRatingAnswers WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyRankingAnswers WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyAnswers WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyResponseDrafts WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyResponses WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyRatingChoiceLabels WHERE SurveyID = @SurveyID;
        DELETE o
        FROM dbo.SurveyQuestionOptions o
        JOIN dbo.SurveyQuestions q ON q.SurveyQuestionID = o.SurveyQuestionID
        WHERE q.SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyReminders WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyAudit WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyQuestions WHERE SurveyID = @SurveyID;
        DELETE FROM dbo.SurveyPosts WHERE SurveyID = @SurveyID;
    END;

    COMMIT TRANSACTION;

    IF @NormalizedContentKind = 'VOTE'
    BEGIN
        SELECT
            (SELECT COUNT_BIG(1) FROM dbo.VotePosts WHERE VotePostID = @VotePostID) AS VotePosts,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostOptions WHERE VotePostID = @VotePostID) AS VotePostOptions,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostVotes WHERE VotePostID = @VotePostID) AS VotePostVotes,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectVotes WHERE VotePostID = @VotePostID) AS VotePostMultiSelectVotes,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostMultiSelectSelections WHERE VotePostID = @VotePostID) AS VotePostMultiSelectSelections,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostReminders WHERE VotePostID = @VotePostID) AS VotePostReminders,
            (SELECT COUNT_BIG(1) FROM dbo.VotePostAudit WHERE VotePostID = @VotePostID) AS VotePostAudit;
    END;
    ELSE
    BEGIN
        SELECT
            (SELECT COUNT_BIG(1) FROM dbo.SurveyPosts WHERE SurveyID = @SurveyID) AS SurveyPosts,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyQuestions WHERE SurveyID = @SurveyID) AS SurveyQuestions,
            (SELECT COUNT_BIG(1)
             FROM dbo.SurveyQuestionOptions o
             JOIN dbo.SurveyQuestions q ON q.SurveyQuestionID = o.SurveyQuestionID
             WHERE q.SurveyID = @SurveyID) AS SurveyQuestionOptions,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyResponses WHERE SurveyID = @SurveyID) AS SurveyResponses,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswers WHERE SurveyID = @SurveyID) AS SurveyAnswers,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyTextAnswers WHERE SurveyID = @SurveyID) AS SurveyTextAnswers,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyAnswerDetails WHERE SurveyID = @SurveyID) AS SurveyAnswerDetails,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingAnswers WHERE SurveyID = @SurveyID) AS SurveyRatingAnswers,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyRankingAnswers WHERE SurveyID = @SurveyID) AS SurveyRankingAnswers,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyRatingChoiceLabels WHERE SurveyID = @SurveyID) AS SurveyRatingChoiceLabels,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyResponseDrafts WHERE SurveyID = @SurveyID) AS SurveyResponseDrafts,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyReminders WHERE SurveyID = @SurveyID) AS SurveyReminders,
            (SELECT COUNT_BIG(1) FROM dbo.SurveyAudit WHERE SurveyID = @SurveyID) AS SurveyAudit;
    END;

    SELECT TOP (1)
        DeletionAuditID, ContentKind, ContentID, Title, Status, DeletedAtUtc, DeletedBy,
        Reason, BreakGlassProductionDelete
    FROM dbo.VoteSurveyDeletionAudit
    WHERE ContentKind = CASE WHEN @NormalizedContentKind = 'VOTE' THEN 'Vote' ELSE 'Survey' END
      AND ContentID = @ContentID
    ORDER BY DeletionAuditID DESC;
END;
GO
