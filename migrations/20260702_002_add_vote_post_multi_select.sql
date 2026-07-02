/*
MigrationId: 20260702_002_add_vote_post_multi_select
Purpose: Add SQL-backed single-question multi-select vote mode storage
Author: cwatts
CreatedUtc: 2026-07-02
RequiresBackup: Yes
RiskLevel: Medium
Rollback: Manual
RollbackScript: N/A
TransactionMode: Auto
DataChange: Yes
DataSafetyPlan: Included
EstimatedRowsAffected: Existing row count in dbo.VotePosts
PreValidationQuery: SELECT COL_LENGTH(N'dbo.VotePosts', N'VoteMode') AS VoteModeColumn, OBJECT_ID(N'dbo.VotePostMultiSelectVotes', N'U') AS MultiSelectVotesObjectId;
PostValidationQuery: SELECT VoteMode, COUNT_BIG(1) AS Rows FROM dbo.VotePosts GROUP BY VoteMode; SELECT OBJECT_ID(N'dbo.VotePostMultiSelectVotes', N'U') AS MultiSelectVotesObjectId, OBJECT_ID(N'dbo.VotePostMultiSelectSelections', N'U') AS MultiSelectSelectionsObjectId;
RelatedBotPR:
RelatedSQLPR:
*/

/*
Data safety note:
Existing vote posts are normalized to OneChoice with MinSelections=1 and MaxSelections=1.
The new multi-select tables are additive and empty at deployment. Existing one-choice votes
continue to use dbo.VotePostVotes, preserving Phase 1-5 behavior and exports. Rollback should
first disable MultiSelect creation in bot code; leave additive tables/columns in place unless a
separate destructive cleanup is explicitly approved after confirming no MultiSelect rows exist.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'VoteMode') IS NULL
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD [VoteMode] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL
            CONSTRAINT [DF_VotePosts_VoteMode] DEFAULT ('OneChoice');
END;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'MinSelections') IS NULL
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD [MinSelections] [tinyint] NOT NULL
            CONSTRAINT [DF_VotePosts_MinSelections] DEFAULT ((1));
END;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'MaxSelections') IS NULL
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD [MaxSelections] [tinyint] NOT NULL
            CONSTRAINT [DF_VotePosts_MaxSelections] DEFAULT ((1));
END;
GO

IF COL_LENGTH(N'dbo.VotePosts', N'VoteMode') IS NOT NULL
BEGIN
    UPDATE [dbo].[VotePosts]
    SET [VoteMode] = 'OneChoice'
    WHERE [VoteMode] IS NULL
       OR [VoteMode] NOT IN ('OneChoice', 'MultiSelect');

    UPDATE [dbo].[VotePosts]
    SET [MinSelections] = 1
    WHERE [MinSelections] IS NULL
       OR [MinSelections] < 1
       OR [VoteMode] = 'OneChoice';

    UPDATE [dbo].[VotePosts]
    SET [MaxSelections] = 1
    WHERE [MaxSelections] IS NULL
       OR [MaxSelections] < [MinSelections]
       OR [MaxSelections] > 6
       OR [VoteMode] = 'OneChoice';

    ALTER TABLE [dbo].[VotePosts]
        ALTER COLUMN [VoteMode] [varchar](30) COLLATE Latin1_General_CI_AS NOT NULL;
    ALTER TABLE [dbo].[VotePosts]
        ALTER COLUMN [MinSelections] [tinyint] NOT NULL;
    ALTER TABLE [dbo].[VotePosts]
        ALTER COLUMN [MaxSelections] [tinyint] NOT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE name = N'DF_VotePosts_VoteMode'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD CONSTRAINT [DF_VotePosts_VoteMode]
        DEFAULT ('OneChoice') FOR [VoteMode];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE name = N'DF_VotePosts_MinSelections'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD CONSTRAINT [DF_VotePosts_MinSelections]
        DEFAULT ((1)) FOR [MinSelections];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints
    WHERE name = N'DF_VotePosts_MaxSelections'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts]
        ADD CONSTRAINT [DF_VotePosts_MaxSelections]
        DEFAULT ((1)) FOR [MaxSelections];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_VotePosts_VoteMode'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts] WITH CHECK
        ADD CONSTRAINT [CK_VotePosts_VoteMode]
        CHECK ([VoteMode] IN ('OneChoice', 'MultiSelect'));
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_VotePosts_SelectionCardinality'
)
BEGIN
    ALTER TABLE [dbo].[VotePosts] WITH CHECK
        ADD CONSTRAINT [CK_VotePosts_SelectionCardinality]
        CHECK (
            [MinSelections] >= 1
            AND [MaxSelections] >= [MinSelections]
            AND [MaxSelections] <= 6
            AND ([VoteMode] <> 'OneChoice' OR ([MinSelections] = 1 AND [MaxSelections] = 1))
            AND ([VoteMode] <> 'MultiSelect' OR [MaxSelections] >= 2)
        );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[VotePostMultiSelectVotes](
        [VotePostID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [OriginalOptionIDsJson] [nvarchar](max) COLLATE Latin1_General_CI_AS NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        [UpdatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_VotePostMultiSelectVotes] PRIMARY KEY CLUSTERED ([VotePostID] ASC, [DiscordUserID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]') AND type = N'U')
BEGIN
    CREATE TABLE [dbo].[VotePostMultiSelectSelections](
        [VotePostID] [bigint] NOT NULL,
        [DiscordUserID] [bigint] NOT NULL,
        [OptionID] [bigint] NOT NULL,
        [CreatedAtUtc] [datetime2](0) NOT NULL,
        CONSTRAINT [PK_VotePostMultiSelectSelections] PRIMARY KEY CLUSTERED ([VotePostID] ASC, [DiscordUserID] ASC, [OptionID] ASC)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VotePostMultiSelectVotes_OriginalOptionIDsJson')
    ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD CONSTRAINT [DF_VotePostMultiSelectVotes_OriginalOptionIDsJson] DEFAULT (N'[]') FOR [OriginalOptionIDsJson];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VotePostMultiSelectVotes_CreatedAtUtc')
    ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD CONSTRAINT [DF_VotePostMultiSelectVotes_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VotePostMultiSelectVotes_UpdatedAtUtc')
    ALTER TABLE [dbo].[VotePostMultiSelectVotes] ADD CONSTRAINT [DF_VotePostMultiSelectVotes_UpdatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [UpdatedAtUtc];
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_VotePostMultiSelectSelections_CreatedAtUtc')
    ALTER TABLE [dbo].[VotePostMultiSelectSelections] ADD CONSTRAINT [DF_VotePostMultiSelectSelections_CreatedAtUtc] DEFAULT (SYSUTCDATETIME()) FOR [CreatedAtUtc];
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_VotePostMultiSelectVotes_VotePosts')
    ALTER TABLE [dbo].[VotePostMultiSelectVotes] WITH CHECK ADD CONSTRAINT [FK_VotePostMultiSelectVotes_VotePosts] FOREIGN KEY([VotePostID]) REFERENCES [dbo].[VotePosts] ([VotePostID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_VotePostMultiSelectSelections_Votes')
    ALTER TABLE [dbo].[VotePostMultiSelectSelections] WITH CHECK ADD CONSTRAINT [FK_VotePostMultiSelectSelections_Votes] FOREIGN KEY([VotePostID], [DiscordUserID]) REFERENCES [dbo].[VotePostMultiSelectVotes] ([VotePostID], [DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_VotePostMultiSelectSelections_Options')
    ALTER TABLE [dbo].[VotePostMultiSelectSelections] WITH CHECK ADD CONSTRAINT [FK_VotePostMultiSelectSelections_Options] FOREIGN KEY([VotePostID], [OptionID]) REFERENCES [dbo].[VotePostOptions] ([VotePostID], [OptionID]);
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_VotePostMultiSelectVotes_OriginalOptionIDsJson'
)
BEGIN
    ALTER TABLE [dbo].[VotePostMultiSelectVotes] WITH CHECK
        ADD CONSTRAINT [CK_VotePostMultiSelectVotes_OriginalOptionIDsJson]
        CHECK (ISJSON([OriginalOptionIDsJson]) = 1);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectVotes]') AND name = N'IX_VotePostMultiSelectVotes_PostUpdated')
    CREATE NONCLUSTERED INDEX [IX_VotePostMultiSelectVotes_PostUpdated] ON [dbo].[VotePostMultiSelectVotes]([VotePostID], [UpdatedAtUtc]) INCLUDE([DiscordUserID]);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[VotePostMultiSelectSelections]') AND name = N'IX_VotePostMultiSelectSelections_PostOption')
    CREATE NONCLUSTERED INDEX [IX_VotePostMultiSelectSelections_PostOption] ON [dbo].[VotePostMultiSelectSelections]([VotePostID], [OptionID]) INCLUDE([DiscordUserID]);
GO
