/*
MigrationId: 20260721_004_return_complete_leadership_alias_history
Purpose: Return complete alias history for the bounded leadership Governor ID set
Author: cwatts
CreatedUtc: 2026-07-21
RequiresBackup: No
RiskLevel: Low
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: 0
PreValidationQuery: SELECT OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory', N'P') AS IdentityProcedure;
PostValidationQuery: SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory', N'P')) AS IdentityDefinition;
RelatedBotPR: https://github.com/cwatts6/k98-bot/pull/537
RelatedSQLPR: https://github.com/cwatts6/K98-bot-SQL-Server/pull/53

Contract change:
- Alias history returns every persisted alias for the requested Governor IDs.
- The request remains bounded to at most 26 exact Governor IDs.
- @HistoryDays continues to bound complete-scan alliance episodes to at most 720 days.
- Result-set columns and ordering are unchanged.
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

DECLARE @IdentityObjectId int = OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory', N'P');
DECLARE @IdentityDefinition nvarchar(max) = OBJECT_DEFINITION(@IdentityObjectId);
DECLARE @AliasDateFilter nvarchar(100) = N'WHERE history_rows.LastSeen >= @StartDate';
DECLARE @AliasDateFilterPosition int = CHARINDEX(@AliasDateFilter, @IdentityDefinition);

IF @IdentityDefinition IS NULL
    THROW 51545, 'dbo.usp_GetLeadershipPlayerIdentityHistory was not found.', 1;

IF @AliasDateFilterPosition > 0
   AND CHARINDEX(
        @AliasDateFilter,
        @IdentityDefinition,
        @AliasDateFilterPosition + LEN(@AliasDateFilter)
   ) > 0
    THROW 51546, 'The expected unique alias history date filter was not found.', 1;

IF @AliasDateFilterPosition > 0
BEGIN
    SET @IdentityDefinition = STUFF(
        @IdentityDefinition,
        @AliasDateFilterPosition,
        LEN(@AliasDateFilter),
        N''
    );

    /* OBJECT_DEFINITION may retain CREATE syntax; replay the module with ALTER semantics. */
    DECLARE @UpperIdentityDefinition nvarchar(max) = UPPER(@IdentityDefinition);
    DECLARE @HeaderPosition int = 1;
    WHILE @HeaderPosition <= LEN(@UpperIdentityDefinition)
          AND UNICODE(SUBSTRING(@UpperIdentityDefinition, @HeaderPosition, 1))
              IN (9, 10, 13, 32)
        SET @HeaderPosition += 1;

    IF @HeaderPosition NOT BETWEEN 1 AND 64
        THROW 51547, 'Leadership identity module header starts outside the allowed prefix.', 1;

    IF SUBSTRING(
           @UpperIdentityDefinition,
           @HeaderPosition,
           LEN(N'CREATE OR ALTER')
       ) = N'CREATE OR ALTER'
        SET @IdentityDefinition = STUFF(
            @IdentityDefinition,
            @HeaderPosition,
            LEN(N'CREATE OR ALTER'),
            N'ALTER'
        );
    ELSE IF SUBSTRING(@UpperIdentityDefinition, @HeaderPosition, LEN(N'CREATE')) = N'CREATE'
        SET @IdentityDefinition = STUFF(
            @IdentityDefinition,
            @HeaderPosition,
            LEN(N'CREATE'),
            N'ALTER'
        );
    ELSE IF SUBSTRING(@UpperIdentityDefinition, @HeaderPosition, LEN(N'ALTER')) <> N'ALTER'
        THROW 51547, 'Leadership identity module header is not CREATE or ALTER.', 1;

    EXEC sys.sp_executesql @IdentityDefinition;
END;
GO

DECLARE @DeployedDefinition nvarchar(max) =
    OBJECT_DEFINITION(OBJECT_ID(N'dbo.usp_GetLeadershipPlayerIdentityHistory', N'P'));

IF @DeployedDefinition IS NULL
   OR CHARINDEX(N'WHERE history_rows.LastSeen >= @StartDate', @DeployedDefinition) > 0
   OR CHARINDEX(N'JOIN @GovernorIDs AS requested', @DeployedDefinition) = 0
   OR CHARINDEX(N'WHERE AsOfDate BETWEEN @StartDate AND @AnchorDate', @DeployedDefinition) = 0
    THROW 51548, 'Complete leadership alias history contract verification failed.', 1;
GO
