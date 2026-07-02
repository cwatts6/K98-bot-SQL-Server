/*
MigrationId: 20260702_001_add_vote_post_result_visibility
Purpose: Add result visibility mode to SQL-backed Discord vote posts
Author: cwatts
CreatedUtc: 2026-07-02
RequiresBackup: Yes
RiskLevel: Low
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Existing row count in dbo.VotePosts
PreValidationQuery: SELECT COL_LENGTH(N'dbo.VotePosts', N'ResultVisibility') AS ResultVisibilityColumn, COUNT_BIG(1) AS VotePostRows FROM dbo.VotePosts;
PostValidationQuery: SELECT ResultVisibility, COUNT_BIG(1) AS Rows FROM dbo.VotePosts GROUP BY ResultVisibility;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
Existing VotePosts rows receive the PublicLive default, preserving Phase 1-4 public
live-result behaviour. No voter rows, option rows, audit rows, or export surfaces are changed.
If the column already exists from a partial/manual deployment, NULL or unexpected values are
normalized to PublicLive before enforcing NOT NULL and the check constraint.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'ResultVisibility') IS NULL
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD [ResultVisibility] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL
            CONSTRAINT [DF_VotePosts_ResultVisibility] DEFAULT ('PublicLive');
END;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'ResultVisibility') IS NOT NULL
BEGIN
    UPDATE [dbo].[VotePosts]
    SET [ResultVisibility] = 'PublicLive'
    WHERE [ResultVisibility] IS NULL
       OR [ResultVisibility] NOT IN ('PublicLive', 'HiddenUntilClose');

    ALTER TABLE [dbo].[VotePosts]
        ALTER COLUMN [ResultVisibility] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE name = N'DF_VotePosts_ResultVisibility'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD CONSTRAINT [DF_VotePosts_ResultVisibility]
        DEFAULT ('PublicLive') FOR [ResultVisibility];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_VotePosts_ResultVisibility'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts] WITH CHECK
        ADD CONSTRAINT [CK_VotePosts_ResultVisibility]
        CHECK ([ResultVisibility] IN ('PublicLive', 'HiddenUntilClose'));
END;
GO
