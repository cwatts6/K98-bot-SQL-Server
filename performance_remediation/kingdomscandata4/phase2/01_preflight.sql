/*
Purpose:
    Drift-guarded Phase 2 preflight for the KingdomScanData4 shadow migration.

Safety:
    - Confirmation variables default to refusal.
    - Production requires a separate explicit confirmation.
    - Refuses a target associated with a database snapshot.
    - Captures exact table/index/statistic/permission/module inventories.
    - Creates and verifies a fresh COPY_ONLY, CHECKSUM backup.
    - Preallocates data-file space outside the application outage.

Operator:
    Set @ConfirmTargetDatabase to DB_NAME().
    Set @ConfirmCreateCopyOnlyBackup = 1.
    Set @ConfirmProduction = 1 only for separately approved production execution.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
SET DEADLOCK_PRIORITY LOW;
SET LOCK_TIMEOUT 10000;

DECLARE @ScriptRevision varchar(20) = '20260725.1';
DECLARE @ConfirmTargetDatabase sysname = N'';
DECLARE @ConfirmCreateCopyOnlyBackup bit = 0;
DECLARE @ConfirmProduction bit = 0;
DECLARE @ProductionDatabase sysname = N'ROK_TRACKER';
DECLARE @RunId uniqueidentifier = NEWID();
DECLARE @StartedAtUtc datetime2(7) = SYSUTCDATETIME();
DECLARE @BackupPath nvarchar(4000);
DECLARE @Sql nvarchar(max);

IF DB_NAME() <> @ConfirmTargetDatabase
    THROW 51500, 'Safety stop: set @ConfirmTargetDatabase to the connected database.', 1;

IF DB_NAME() = @ProductionDatabase AND @ConfirmProduction <> 1
    THROW 51501, 'Production execution requires separate explicit confirmation.', 1;

IF DB_NAME() <> @ProductionDatabase
   AND DB_NAME() NOT LIKE N'ROK[_]TRACKER[_]BACKUP[_]TEST[_]KS4%'
    THROW 51502, 'Safety stop: target is neither production nor an approved KS4 representative copy.', 1;

IF @ConfirmCreateCopyOnlyBackup <> 1
    THROW 51503, 'Safety stop: confirm the fresh copy-only backup.', 1;

IF @@TRANCOUNT <> 0
    THROW 51504, 'Run preflight with no existing user transaction.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.databases
    WHERE source_database_id = DB_ID()
       OR (database_id = DB_ID() AND source_database_id IS NOT NULL)
)
    THROW 51505, 'A database snapshot is associated with the target; use the no-snapshot representative copy.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4', N'U') IS NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5', N'U') IS NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING', N'U') IS NULL
    THROW 51506, 'One or more canonical source tables are absent.', 1;

IF OBJECT_ID(N'dbo.KingdomScanData4_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData4_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.KingdomScanData5_Phase2_Failed', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_New', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Old', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.IMPORT_STAGING_Phase2_Failed', N'U') IS NOT NULL
    THROW 51507, 'Prior Phase 2 table artifacts exist; restore the representative seed or complete the documented recovery branch.', 1;

IF EXISTS
(
    SELECT 1
    FROM sys.dm_exec_sessions AS session_info
    LEFT JOIN sys.dm_exec_requests AS request_info
      ON request_info.session_id = session_info.session_id
    WHERE session_info.is_user_process = 1
      AND session_info.session_id <> @@SPID
      AND COALESCE(request_info.database_id, session_info.database_id) = DB_ID()
      AND NOT
      (
          session_info.program_name LIKE N'Microsoft SQL Server Management Studio%IntelliSense%'
          AND request_info.session_id IS NULL
          AND session_info.open_transaction_count = 0
          AND session_info.status = N'sleeping'
      )
)
    THROW 51508, 'Conflicting user sessions are connected; stop bot/import/admin entry points and retry.', 1;

IF OBJECT_ID(N'dbo.KS4_Phase2_PreflightState', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.KS4_Phase2_PreflightState
    (
        RunId uniqueidentifier NOT NULL
            CONSTRAINT PK_KS4_Phase2_PreflightState PRIMARY KEY,
        ScriptRevision varchar(20) NOT NULL,
        DatabaseName sysname NOT NULL,
        ServerName sysname NOT NULL,
        ProductionApproved bit NOT NULL,
        StartedAtUtc datetime2(7) NOT NULL,
        CompletedAtUtc datetime2(7) NULL,
        ExpiresAtUtc datetime2(7) NULL,
        BackupPath nvarchar(4000) NULL,
        BackupVerified bit NOT NULL
            CONSTRAINT DF_KS4_Phase2_Preflight_BackupVerified DEFAULT (0),
        Ks4Rows bigint NULL,
        Ks5Rows bigint NULL,
        StagingRows bigint NULL,
        Ks4MaxScan int NULL,
        Ks5MaxScan int NULL,
        ColumnInventoryHash varbinary(32) NULL,
        IndexInventoryHash varbinary(32) NULL,
        StatisticInventoryHash varbinary(32) NULL,
        PermissionInventoryHash varbinary(32) NULL,
        ModuleInventoryHash varbinary(32) NULL,
        Status varchar(16) NOT NULL,
        FailureMessage nvarchar(2048) NULL,
        MigrationStartedAtUtc datetime2(7) NULL,
        MigrationCompletedAtUtc datetime2(7) NULL,
        VerifiedAtUtc datetime2(7) NULL,
        RollbackCompletedAtUtc datetime2(7) NULL,
        FinalizedAtUtc datetime2(7) NULL,
        BaselineKs4Digest varbinary(32) NULL,
        BaselineKs5Digest varbinary(32) NULL,
        BaselineStagingDigest varbinary(32) NULL,
        ForwardKs4Digest varbinary(32) NULL,
        ForwardKs5Digest varbinary(32) NULL,
        ForwardStagingDigest varbinary(32) NULL
    );

    CREATE TABLE dbo.KS4_Phase2_ColumnInventory
    (
        RunId uniqueidentifier NOT NULL,
        ObjectName sysname NOT NULL,
        ColumnId int NOT NULL,
        ColumnName sysname NOT NULL,
        TypeName sysname NOT NULL,
        MaxLength smallint NOT NULL,
        [Precision] tinyint NOT NULL,
        Scale tinyint NOT NULL,
        CollationName sysname NULL,
        IsNullable bit NOT NULL,
        IsIdentity bit NOT NULL,
        IdentitySeed sql_variant NULL,
        IdentityIncrement sql_variant NULL,
        IsComputed bit NOT NULL,
        IsPersisted bit NULL,
        ComputedDefinition nvarchar(max) NULL,
        DefaultName sysname NULL,
        DefaultDefinition nvarchar(max) NULL,
        CONSTRAINT PK_KS4_Phase2_ColumnInventory
            PRIMARY KEY (RunId, ObjectName, ColumnId)
    );

    CREATE TABLE dbo.KS4_Phase2_IndexInventory
    (
        RunId uniqueidentifier NOT NULL,
        ObjectName sysname NOT NULL,
        IndexName sysname NOT NULL,
        TypeDesc nvarchar(60) NOT NULL,
        IsUnique bit NOT NULL,
        IsPrimaryKey bit NOT NULL,
        IsDisabled bit NOT NULL,
        HasFilter bit NOT NULL,
        FilterDefinition nvarchar(max) NULL,
        KeyColumns nvarchar(max) NOT NULL,
        IncludeColumns nvarchar(max) NULL,
        CONSTRAINT PK_KS4_Phase2_IndexInventory
            PRIMARY KEY (RunId, ObjectName, IndexName)
    );

    CREATE TABLE dbo.KS4_Phase2_StatisticInventory
    (
        RunId uniqueidentifier NOT NULL,
        ObjectName sysname NOT NULL,
        StatisticName sysname NOT NULL,
        IsAutoCreated bit NOT NULL,
        IsUserCreated bit NOT NULL,
        NoRecompute bit NOT NULL,
        HasFilter bit NOT NULL,
        FilterDefinition nvarchar(max) NULL,
        StatisticColumns nvarchar(max) NOT NULL,
        CONSTRAINT PK_KS4_Phase2_StatisticInventory
            PRIMARY KEY (RunId, ObjectName, StatisticName)
    );

    CREATE TABLE dbo.KS4_Phase2_PermissionInventory
    (
        RunId uniqueidentifier NOT NULL,
        ObjectName sysname NOT NULL,
        PrincipalName sysname NOT NULL,
        StateCode char(1) NOT NULL,
        PermissionName sysname NOT NULL,
        ColumnId int NOT NULL,
        CONSTRAINT PK_KS4_Phase2_PermissionInventory
            PRIMARY KEY
            (RunId, ObjectName, PrincipalName, PermissionName, ColumnId)
    );

    CREATE TABLE dbo.KS4_Phase2_ModuleInventory
    (
        RunId uniqueidentifier NOT NULL,
        SchemaName sysname NOT NULL,
        ObjectName sysname NOT NULL,
        ObjectType char(2) NOT NULL,
        DefinitionHash varbinary(32) NOT NULL,
        UsesAnsiNulls bit NOT NULL,
        UsesQuotedIdentifier bit NOT NULL,
        CONSTRAINT PK_KS4_Phase2_ModuleInventory
            PRIMARY KEY (RunId, SchemaName, ObjectName)
    );

    CREATE TABLE dbo.KS4_Phase2_MigrationReceipt
    (
        ReceiptId bigint IDENTITY(1, 1) NOT NULL
            CONSTRAINT PK_KS4_Phase2_MigrationReceipt PRIMARY KEY,
        RunId uniqueidentifier NOT NULL,
        Direction varchar(16) NOT NULL,
        StepName nvarchar(128) NOT NULL,
        StartedAtUtc datetime2(7) NOT NULL,
        FinishedAtUtc datetime2(7) NOT NULL,
        DurationMs decimal(19, 3) NOT NULL,
        RowsAffected bigint NULL,
        Notes nvarchar(1000) NULL
    );
END;

INSERT dbo.KS4_Phase2_PreflightState
(
    RunId, ScriptRevision, DatabaseName, ServerName, ProductionApproved,
    StartedAtUtc, Status
)
VALUES
(
    @RunId, @ScriptRevision, DB_NAME(), @@SERVERNAME, @ConfirmProduction,
    @StartedAtUtc, 'STARTED'
);

BEGIN TRY
    DECLARE @ExpectedTypes table
    (
        ObjectName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        TypeName sysname NOT NULL,
        MaxLength smallint NOT NULL,
        IsNullable bit NOT NULL,
        PRIMARY KEY (ObjectName, ColumnName)
    );

    INSERT @ExpectedTypes
        (ObjectName, ColumnName, TypeName, MaxLength, IsNullable)
    VALUES
        (N'KingdomScanData4', N'PowerRank', N'float', 8, 0),
        (N'KingdomScanData4', N'GovernorName', N'nchar', 510, 1),
        (N'KingdomScanData4', N'GovernorID', N'float', 8, 0),
        (N'KingdomScanData4', N'Alliance', N'nchar', 510, 1),
        (N'KingdomScanData4', N'Power', N'float', 8, 0),
        (N'KingdomScanData4', N'KillPoints', N'float', 8, 0),
        (N'KingdomScanData4', N'Deads', N'float', 8, 0),
        (N'KingdomScanData4', N'T1_Kills', N'float', 8, 0),
        (N'KingdomScanData4', N'T2_Kills', N'float', 8, 0),
        (N'KingdomScanData4', N'T3_Kills', N'float', 8, 0),
        (N'KingdomScanData4', N'T4_Kills', N'float', 8, 0),
        (N'KingdomScanData4', N'T5_Kills', N'float', 8, 0),
        (N'KingdomScanData4', N'T4&T5_KILLS', N'float', 8, 1),
        (N'KingdomScanData4', N'TOTAL_KILLS', N'float', 8, 1),
        (N'KingdomScanData4', N'RSS_Gathered', N'float', 8, 1),
        (N'KingdomScanData4', N'RSSAssistance', N'float', 8, 0),
        (N'KingdomScanData4', N'Helps', N'float', 8, 0),
        (N'KingdomScanData4', N'SCANORDER', N'float', 8, 0),
        (N'KingdomScanData5', N'PowerRank', N'float', 8, 0),
        (N'KingdomScanData5', N'GovernorName', N'nchar', 510, 1),
        (N'KingdomScanData5', N'GovernorID', N'float', 8, 0),
        (N'KingdomScanData5', N'Alliance', N'nchar', 510, 1),
        (N'KingdomScanData5', N'Power', N'float', 8, 0),
        (N'KingdomScanData5', N'KillPoints', N'float', 8, 0),
        (N'KingdomScanData5', N'Deads', N'float', 8, 0),
        (N'KingdomScanData5', N'T1_Kills', N'float', 8, 0),
        (N'KingdomScanData5', N'T2_Kills', N'float', 8, 0),
        (N'KingdomScanData5', N'T3_Kills', N'float', 8, 0),
        (N'KingdomScanData5', N'T4_Kills', N'float', 8, 0),
        (N'KingdomScanData5', N'T5_Kills', N'float', 8, 0),
        (N'KingdomScanData5', N'T4&T5_KILLS', N'float', 8, 1),
        (N'KingdomScanData5', N'TOTAL_KILLS', N'float', 8, 1),
        (N'KingdomScanData5', N'RSS_Gathered', N'float', 8, 1),
        (N'KingdomScanData5', N'RSSAssistance', N'float', 8, 0),
        (N'KingdomScanData5', N'Helps', N'float', 8, 0),
        (N'KingdomScanData5', N'SCANORDER', N'float', 8, 1),
        (N'IMPORT_STAGING', N'Name', N'nchar', 510, 1),
        (N'IMPORT_STAGING', N'Governor ID', N'float', 8, 0),
        (N'IMPORT_STAGING', N'Alliance', N'nchar', 510, 1),
        (N'IMPORT_STAGING', N'Power', N'float', 8, 0),
        (N'IMPORT_STAGING', N'Total Kill Points', N'float', 8, 0),
        (N'IMPORT_STAGING', N'Dead Troops', N'float', 8, 0),
        (N'IMPORT_STAGING', N'T1-Kills', N'float', 8, 0),
        (N'IMPORT_STAGING', N'T2-Kills', N'float', 8, 0),
        (N'IMPORT_STAGING', N'T3-Kills', N'float', 8, 0),
        (N'IMPORT_STAGING', N'T4-Kills', N'float', 8, 0),
        (N'IMPORT_STAGING', N'T5-Kills', N'float', 8, 0),
        (N'IMPORT_STAGING', N'Kills (T4+)', N'float', 8, 1),
        (N'IMPORT_STAGING', N'KILLS', N'float', 8, 1),
        (N'IMPORT_STAGING', N'RSS Gathered', N'float', 8, 1),
        (N'IMPORT_STAGING', N'RSS Assistance', N'float', 8, 0),
        (N'IMPORT_STAGING', N'Alliance Helps', N'float', 8, 0),
        (N'IMPORT_STAGING', N'SCANORDER', N'float', 8, 1),
        (N'IMPORT_STAGING', N'Updated_on', N'varchar', 50, 1);

    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedTypes AS expected
        LEFT JOIN sys.columns AS column_info
          ON column_info.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
         AND column_info.name = expected.ColumnName
        LEFT JOIN sys.types AS type_info
          ON type_info.user_type_id = column_info.user_type_id
        WHERE column_info.column_id IS NULL
           OR type_info.name <> expected.TypeName
           OR column_info.max_length <> expected.MaxLength
           OR column_info.is_nullable <> expected.IsNullable
    )
        THROW 51509, 'Source type or nullability drift detected.', 1;

    DECLARE @ExpectedOrder table
    (
        ObjectName sysname NOT NULL PRIMARY KEY,
        ColumnOrder nvarchar(max) NOT NULL
    );

    INSERT @ExpectedOrder (ObjectName, ColumnOrder)
    VALUES
    (
        N'KingdomScanData4',
        N'[PowerRank]|[GovernorName]|[GovernorID]|[Alliance]|[Power]|[KillPoints]|[Deads]|[T1_Kills]|[T2_Kills]|[T3_Kills]|[T4_Kills]|[T5_Kills]|[T4&T5_KILLS]|[TOTAL_KILLS]|[RSS_Gathered]|[RSSAssistance]|[Helps]|[ScanDate]|[SCANORDER]|[SCAN_UNO]|[Troops Power]|[City Hall]|[Tech Power]|[Building Power]|[Commander Power]|[AsOfDate]|[HealedTroops]|[RangedPoints]|[Civilization]|[KvKPlayed]|[MostKvKKill]|[MostKvKDead]|[MostKvKHeal]|[Acclaim]|[HighestAcclaim]|[AOOJoined]|[AOOWon]|[AOOAvgKill]|[AOOAvgDead]|[AOOAvgHeal]|[AutarchTimes]|[Conduct]'
    ),
    (
        N'KingdomScanData5',
        N'[PowerRank]|[GovernorName]|[GovernorID]|[Alliance]|[Power]|[KillPoints]|[Deads]|[T1_Kills]|[T2_Kills]|[T3_Kills]|[T4_Kills]|[T5_Kills]|[T4&T5_KILLS]|[TOTAL_KILLS]|[RSS_Gathered]|[RSSAssistance]|[Helps]|[ScanDate]|[SCANORDER]|[SCAN_UNO]|[Troops Power]|[City Hall]|[Tech Power]|[Building Power]|[Commander Power]|[HealedTroops]|[RangedPoints]|[Civilization]|[KvKPlayed]|[MostKvKKill]|[MostKvKDead]|[MostKvKHeal]|[Acclaim]|[HighestAcclaim]|[AOOJoined]|[AOOWon]|[AOOAvgKill]|[AOOAvgDead]|[AOOAvgHeal]|[AutarchTimes]|[Conduct]'
    ),
    (
        N'IMPORT_STAGING',
        N'[Name]|[Governor ID]|[Alliance]|[Power]|[Total Kill Points]|[Dead Troops]|[T1-Kills]|[T2-Kills]|[T3-Kills]|[T4-Kills]|[T5-Kills]|[Kills (T4+)]|[KILLS]|[RSS Gathered]|[RSS Assistance]|[Alliance Helps]|[ScanDate]|[SCANORDER]|[Troops Power]|[City Hall]|[Tech Power]|[Building Power]|[Commander Power]|[Updated_on]|[HealedTroops]|[RangedPoints]|[Civilization]|[KvKPlayed]|[MostKvKKill]|[MostKvKDead]|[MostKvKHeal]|[Acclaim]|[HighestAcclaim]|[AOOJoined]|[AOOWon]|[AOOAvgKill]|[AOOAvgDead]|[AOOAvgHeal]|[AutarchTimes]|[Conduct]'
    );

    IF EXISTS
    (
        SELECT 1
        FROM @ExpectedOrder AS expected
        CROSS APPLY
        (
            SELECT STRING_AGG(CONVERT(nvarchar(max), QUOTENAME(column_info.name)), N'|')
                WITHIN GROUP (ORDER BY column_info.column_id) AS ActualOrder
            FROM sys.columns AS column_info
            WHERE column_info.object_id = OBJECT_ID(N'dbo.' + expected.ObjectName)
        ) AS actual
        WHERE actual.ActualOrder <> expected.ColumnOrder
    )
        THROW 51510, 'Source column order drift detected.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.computed_columns
        WHERE object_id = OBJECT_ID(N'dbo.KingdomScanData4')
          AND name = N'AsOfDate'
          AND is_persisted = 1
          AND definition = N'(CONVERT([date],[ScanDate]))'
    )
        THROW 51511, 'Persisted AsOfDate contract drift detected.', 1;

    IF COLUMNPROPERTY(OBJECT_ID(N'dbo.KingdomScanData5'), N'SCAN_UNO', 'IsIdentity') <> 1
       OR IDENT_SEED(N'dbo.KingdomScanData5') <> 1
       OR IDENT_INCR(N'dbo.KingdomScanData5') <> 1
        THROW 51512, 'KingdomScanData5 identity contract drift detected.', 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.default_constraints
        WHERE parent_object_id = OBJECT_ID(N'dbo.KingdomScanData4')
          AND name = N'DF_KS4_SCAN_UNO'
          AND definition = N'(NEXT VALUE FOR [dbo].[KS4_UNO_SEQ])'
    )
        THROW 51513, 'KingdomScanData4 sequence-default contract drift detected.', 1;

    DECLARE @ConversionEvidence table
    (
        ObjectName sysname NOT NULL,
        ColumnName sysname NOT NULL,
        TargetType sysname NOT NULL,
        FractionalCount bigint NOT NULL,
        IntOutOfRangeCount bigint NOT NULL,
        BigintFailedCount bigint NOT NULL,
        PRIMARY KEY (ObjectName, ColumnName)
    );

    ;WITH ValuesToCheck AS
    (
        SELECT N'KingdomScanData4' AS ObjectName, checked.ColumnName,
               checked.TargetType, checked.CandidateValue
        FROM dbo.KingdomScanData4 AS source
        CROSS APPLY (VALUES
            (N'GovernorID', N'bigint', source.GovernorID),
            (N'PowerRank', N'int', source.PowerRank),
            (N'SCANORDER', N'int', source.SCANORDER),
            (N'Power', N'bigint', source.Power),
            (N'KillPoints', N'bigint', source.KillPoints),
            (N'Deads', N'bigint', source.Deads),
            (N'T1_Kills', N'bigint', source.T1_Kills),
            (N'T2_Kills', N'bigint', source.T2_Kills),
            (N'T3_Kills', N'bigint', source.T3_Kills),
            (N'T4_Kills', N'bigint', source.T4_Kills),
            (N'T5_Kills', N'bigint', source.T5_Kills),
            (N'T4&T5_KILLS', N'bigint', source.[T4&T5_KILLS]),
            (N'TOTAL_KILLS', N'bigint', source.TOTAL_KILLS),
            (N'RSS_Gathered', N'bigint', source.RSS_Gathered),
            (N'RSSAssistance', N'bigint', source.RSSAssistance),
            (N'Helps', N'bigint', source.Helps)
        ) AS checked(ColumnName, TargetType, CandidateValue)
        UNION ALL
        SELECT N'KingdomScanData5', checked.ColumnName,
               checked.TargetType, checked.CandidateValue
        FROM dbo.KingdomScanData5 AS source
        CROSS APPLY (VALUES
            (N'GovernorID', N'bigint', source.GovernorID),
            (N'PowerRank', N'int', source.PowerRank),
            (N'SCANORDER', N'int', source.SCANORDER),
            (N'Power', N'bigint', source.Power),
            (N'KillPoints', N'bigint', source.KillPoints),
            (N'Deads', N'bigint', source.Deads),
            (N'T1_Kills', N'bigint', source.T1_Kills),
            (N'T2_Kills', N'bigint', source.T2_Kills),
            (N'T3_Kills', N'bigint', source.T3_Kills),
            (N'T4_Kills', N'bigint', source.T4_Kills),
            (N'T5_Kills', N'bigint', source.T5_Kills),
            (N'T4&T5_KILLS', N'bigint', source.[T4&T5_KILLS]),
            (N'TOTAL_KILLS', N'bigint', source.TOTAL_KILLS),
            (N'RSS_Gathered', N'bigint', source.RSS_Gathered),
            (N'RSSAssistance', N'bigint', source.RSSAssistance),
            (N'Helps', N'bigint', source.Helps)
        ) AS checked(ColumnName, TargetType, CandidateValue)
        UNION ALL
        SELECT N'IMPORT_STAGING', checked.ColumnName,
               checked.TargetType, checked.CandidateValue
        FROM dbo.IMPORT_STAGING AS source
        CROSS APPLY (VALUES
            (N'Governor ID', N'bigint', source.[Governor ID]),
            (N'SCANORDER', N'int', source.SCANORDER),
            (N'Power', N'bigint', source.Power),
            (N'Total Kill Points', N'bigint', source.[Total Kill Points]),
            (N'Dead Troops', N'bigint', source.[Dead Troops]),
            (N'T1-Kills', N'bigint', source.[T1-Kills]),
            (N'T2-Kills', N'bigint', source.[T2-Kills]),
            (N'T3-Kills', N'bigint', source.[T3-Kills]),
            (N'T4-Kills', N'bigint', source.[T4-Kills]),
            (N'T5-Kills', N'bigint', source.[T5-Kills]),
            (N'Kills (T4+)', N'bigint', source.[Kills (T4+)]),
            (N'KILLS', N'bigint', source.KILLS),
            (N'RSS Gathered', N'bigint', source.[RSS Gathered]),
            (N'RSS Assistance', N'bigint', source.[RSS Assistance]),
            (N'Alliance Helps', N'bigint', source.[Alliance Helps])
        ) AS checked(ColumnName, TargetType, CandidateValue)
    )
    INSERT @ConversionEvidence
        (ObjectName, ColumnName, TargetType, FractionalCount,
         IntOutOfRangeCount, BigintFailedCount)
    SELECT
        ObjectName,
        ColumnName,
        TargetType,
        SUM(CASE WHEN CandidateValue IS NOT NULL
                      AND CandidateValue <> FLOOR(CandidateValue)
                 THEN CONVERT(bigint, 1) ELSE 0 END),
        SUM(CASE WHEN TargetType = N'int'
                      AND CandidateValue IS NOT NULL
                      AND (CandidateValue < -2147483648.0
                           OR CandidateValue > 2147483647.0)
                 THEN CONVERT(bigint, 1) ELSE 0 END),
        SUM(CASE WHEN TargetType = N'bigint'
                      AND CandidateValue IS NOT NULL
                      AND TRY_CONVERT(bigint, CandidateValue) IS NULL
                 THEN CONVERT(bigint, 1) ELSE 0 END)
    FROM ValuesToCheck
    GROUP BY ObjectName, ColumnName, TargetType;

    IF EXISTS
    (
        SELECT 1
        FROM @ConversionEvidence
        WHERE FractionalCount <> 0
           OR IntOutOfRangeCount <> 0
           OR BigintFailedCount <> 0
    )
        THROW 51514, 'Numeric conversion preflight failed.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT MAX(LEN(RTRIM(GovernorName))) AS MaximumLength, 200 AS TargetLength
            FROM dbo.KingdomScanData4
            UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
            FROM dbo.KingdomScanData4
            UNION ALL SELECT MAX(LEN(RTRIM(GovernorName))), 200
            FROM dbo.KingdomScanData5
            UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
            FROM dbo.KingdomScanData5
            UNION ALL SELECT MAX(LEN(RTRIM(Name))), 200
            FROM dbo.IMPORT_STAGING
            UNION ALL SELECT MAX(LEN(RTRIM(Alliance))), 100
            FROM dbo.IMPORT_STAGING
            UNION ALL SELECT MAX(LEN(Updated_on)), 200
            FROM dbo.IMPORT_STAGING
        ) AS lengths
        WHERE lengths.MaximumLength > lengths.TargetLength
    )
        THROW 51515, 'String-width preflight failed.', 1;

    IF
    (
        SELECT COUNT(DISTINCT CONVERT(varbinary(8), GovernorID))
        FROM dbo.KingdomScanData4
    ) <>
    (
        SELECT COUNT(DISTINCT CONVERT(bigint, GovernorID))
        FROM dbo.KingdomScanData4
    )
        THROW 51516, 'GovernorID conversion collision detected.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.sql_expression_dependencies
        WHERE referenced_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
          AND OBJECTPROPERTYEX(referencing_id, 'IsSchemaBound') = 1
    )
        THROW 51517, 'Schema-bound dependency prevents the metadata swap.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE parent_object_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
           OR referenced_object_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
    )
       OR EXISTS
    (
        SELECT 1
        FROM sys.triggers
        WHERE parent_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
    )
        THROW 51518, 'Unexpected foreign key or trigger requires a different migration branch.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.extended_properties
        WHERE class = 1
          AND major_id IN
          (
              OBJECT_ID(N'dbo.KingdomScanData4'),
              OBJECT_ID(N'dbo.KingdomScanData5'),
              OBJECT_ID(N'dbo.IMPORT_STAGING')
          )
    )
        THROW 51519, 'Unexpected extended properties require explicit preservation.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM sys.crypt_properties AS signature_info
        JOIN sys.sql_expression_dependencies AS dependency_info
          ON dependency_info.referencing_id = signature_info.major_id
        WHERE dependency_info.referenced_id IN
        (
            OBJECT_ID(N'dbo.KingdomScanData4'),
            OBJECT_ID(N'dbo.KingdomScanData5'),
            OBJECT_ID(N'dbo.IMPORT_STAGING')
        )
    )
        THROW 51520, 'A signed dependent module requires explicit signature handling.', 1;

    INSERT dbo.KS4_Phase2_ColumnInventory
    (
        RunId, ObjectName, ColumnId, ColumnName, TypeName, MaxLength,
        [Precision], Scale, CollationName, IsNullable, IsIdentity,
        IdentitySeed, IdentityIncrement, IsComputed, IsPersisted,
        ComputedDefinition, DefaultName, DefaultDefinition
    )
    SELECT
        @RunId,
        OBJECT_NAME(column_info.object_id),
        column_info.column_id,
        column_info.name,
        type_info.name,
        column_info.max_length,
        column_info.precision,
        column_info.scale,
        column_info.collation_name,
        column_info.is_nullable,
        column_info.is_identity,
        identity_info.seed_value,
        identity_info.increment_value,
        column_info.is_computed,
        computed_info.is_persisted,
        computed_info.definition,
        default_info.name,
        default_info.definition
    FROM sys.columns AS column_info
    JOIN sys.types AS type_info
      ON type_info.user_type_id = column_info.user_type_id
    LEFT JOIN sys.identity_columns AS identity_info
      ON identity_info.object_id = column_info.object_id
     AND identity_info.column_id = column_info.column_id
    LEFT JOIN sys.computed_columns AS computed_info
      ON computed_info.object_id = column_info.object_id
     AND computed_info.column_id = column_info.column_id
    LEFT JOIN sys.default_constraints AS default_info
      ON default_info.object_id = column_info.default_object_id
    WHERE column_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    );

    INSERT dbo.KS4_Phase2_IndexInventory
    (
        RunId, ObjectName, IndexName, TypeDesc, IsUnique, IsPrimaryKey,
        IsDisabled, HasFilter, FilterDefinition, KeyColumns, IncludeColumns
    )
    SELECT
        @RunId,
        OBJECT_NAME(index_info.object_id),
        index_info.name,
        index_info.type_desc,
        index_info.is_unique,
        index_info.is_primary_key,
        index_info.is_disabled,
        index_info.has_filter,
        index_info.filter_definition,
        key_columns.ColumnList,
        include_columns.ColumnList
    FROM sys.indexes AS index_info
    CROSS APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max),
                QUOTENAME(column_info.name)
                + CASE WHEN index_column.is_descending_key = 1
                       THEN N' DESC' ELSE N' ASC' END),
            N',') WITHIN GROUP (ORDER BY index_column.key_ordinal) AS ColumnList
        FROM sys.index_columns AS index_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = index_column.object_id
         AND column_info.column_id = index_column.column_id
        WHERE index_column.object_id = index_info.object_id
          AND index_column.index_id = index_info.index_id
          AND index_column.key_ordinal > 0
    ) AS key_columns
    OUTER APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
            N',') WITHIN GROUP (ORDER BY index_column.index_column_id) AS ColumnList
        FROM sys.index_columns AS index_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = index_column.object_id
         AND column_info.column_id = index_column.column_id
        WHERE index_column.object_id = index_info.object_id
          AND index_column.index_id = index_info.index_id
          AND index_column.is_included_column = 1
    ) AS include_columns
    WHERE index_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND index_info.index_id > 0;

    DECLARE @ExpectedKs4Indexes table
    (
        IndexName sysname NOT NULL PRIMARY KEY,
        TypeDesc nvarchar(60) NOT NULL,
        KeyColumns nvarchar(max) NOT NULL,
        IncludeColumns nvarchar(max) NULL
    );

    INSERT @ExpectedKs4Indexes
        (IndexName, TypeDesc, KeyColumns, IncludeColumns)
    VALUES
        (N'CIX_KS4_ScanOrder_Governor', N'CLUSTERED',
         N'[SCANORDER] ASC,[GovernorID] ASC', NULL),
        (N'IX_KS4_AsOf_Governor', N'NONCLUSTERED',
         N'[AsOfDate] ASC,[GovernorID] ASC',
         N'[TOTAL_KILLS],[KillPoints],[Deads],[Helps],[RSS_Gathered],[RSSAssistance],[Power],[GovernorName]'),
        (N'IX_KS4_Governor_ScanDate', N'NONCLUSTERED',
         N'[GovernorID] ASC,[ScanDate] ASC',
         N'[Power],[KillPoints],[T4&T5_KILLS],[Deads],[GovernorName]'),
        (N'IX_KSD4_Governor_ScanOrder', N'NONCLUSTERED',
         N'[GovernorID] ASC,[SCANORDER] DESC,[AsOfDate] DESC,[ScanDate] DESC',
         N'[GovernorName],[Alliance]'),
        (N'IX_KSD4_Gov_ScanOrder', N'NONCLUSTERED',
         N'[GovernorID] ASC,[SCANORDER] ASC',
         N'[PowerRank],[ScanDate]'),
        (N'IX_kingdomscandata4_ScanOrder_DESC', N'NONCLUSTERED',
         N'[SCANORDER] DESC', NULL),
        (N'IX_KS4_Governor_ScanDate_ScanOrder', N'NONCLUSTERED',
         N'[GovernorID] ASC,[ScanDate] ASC,[SCANORDER] ASC',
         N'[Deads],[GovernorName],[PowerRank]'),
        (N'IX_KingdomScanData4_GovernorID_ScanOrder_Covering', N'NONCLUSTERED',
         N'[GovernorID] ASC,[SCANORDER] ASC',
         N'[ScanDate],[GovernorName],[PowerRank],[Power],[T5_Kills],[T4_Kills],[T4&T5_KILLS],[HealedTroops],[Deads],[RangedPoints],[KillPoints]'),
        (N'IX_KingdomScanData4_ScanOrder_GovernorID', N'NONCLUSTERED',
         N'[SCANORDER] ASC,[GovernorID] ASC',
         N'[ScanDate],[GovernorName],[PowerRank],[Deads],[HealedTroops]'),
        (N'IX_KingdomScanData4_GovernorID_ScanOrder', N'NONCLUSTERED',
         N'[GovernorID] ASC,[SCANORDER] ASC',
         N'[ScanDate],[GovernorName],[PowerRank],[Deads],[HealedTroops]');

    IF (SELECT COUNT(*) FROM dbo.KS4_Phase2_IndexInventory
        WHERE RunId = @RunId AND ObjectName = N'KingdomScanData4') <> 10
       OR EXISTS
    (
        SELECT IndexName, TypeDesc, KeyColumns, IncludeColumns
        FROM @ExpectedKs4Indexes
        EXCEPT
        SELECT IndexName, TypeDesc, KeyColumns, IncludeColumns
        FROM dbo.KS4_Phase2_IndexInventory
        WHERE RunId = @RunId AND ObjectName = N'KingdomScanData4'
    )
       OR EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_IndexInventory
        WHERE RunId = @RunId
          AND ObjectName = N'KingdomScanData4'
          AND (IsUnique <> 0 OR IsPrimaryKey <> 0 OR IsDisabled <> 0
               OR HasFilter <> 0)
    )
       OR NOT EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_IndexInventory
        WHERE RunId = @RunId
          AND ObjectName = N'KingdomScanData5'
          AND TypeDesc = N'CLUSTERED'
          AND IsUnique = 1
          AND IsPrimaryKey = 1
          AND IsDisabled = 0
          AND HasFilter = 0
          AND KeyColumns = N'[SCAN_UNO] ASC'
          AND IncludeColumns IS NULL
    )
       OR (SELECT COUNT(*) FROM dbo.KS4_Phase2_IndexInventory
           WHERE RunId = @RunId AND ObjectName = N'KingdomScanData5') <> 1
       OR EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_IndexInventory
        WHERE RunId = @RunId
          AND ObjectName = N'IMPORT_STAGING'
    )
        THROW 51521, 'The approved KS4/KS5/staging index contract drifted.', 1;

    INSERT dbo.KS4_Phase2_StatisticInventory
    (
        RunId, ObjectName, StatisticName, IsAutoCreated, IsUserCreated,
        NoRecompute, HasFilter, FilterDefinition, StatisticColumns
    )
    SELECT
        @RunId,
        OBJECT_NAME(stat_info.object_id),
        stat_info.name,
        stat_info.auto_created,
        stat_info.user_created,
        stat_info.no_recompute,
        stat_info.has_filter,
        stat_info.filter_definition,
        stat_columns.ColumnList
    FROM sys.stats AS stat_info
    CROSS APPLY
    (
        SELECT STRING_AGG(
            CONVERT(nvarchar(max), QUOTENAME(column_info.name)),
            N',') WITHIN GROUP (ORDER BY stat_column.stats_column_id) AS ColumnList
        FROM sys.stats_columns AS stat_column
        JOIN sys.columns AS column_info
          ON column_info.object_id = stat_column.object_id
         AND column_info.column_id = stat_column.column_id
        WHERE stat_column.object_id = stat_info.object_id
          AND stat_column.stats_id = stat_info.stats_id
    ) AS stat_columns
    LEFT JOIN sys.indexes AS index_info
      ON index_info.object_id = stat_info.object_id
     AND index_info.index_id = stat_info.stats_id
    WHERE stat_info.object_id IN
    (
        OBJECT_ID(N'dbo.KingdomScanData4'),
        OBJECT_ID(N'dbo.KingdomScanData5'),
        OBJECT_ID(N'dbo.IMPORT_STAGING')
    )
      AND index_info.index_id IS NULL;

    DECLARE @ExpectedKs4StatisticColumns table
    (
        StatisticColumns nvarchar(258) NOT NULL PRIMARY KEY
    );
    INSERT @ExpectedKs4StatisticColumns (StatisticColumns)
    VALUES
        (N'[GovernorID]'), (N'[SCANORDER]'), (N'[PowerRank]'),
        (N'[Power]'), (N'[GovernorName]'), (N'[ScanDate]'),
        (N'[SCAN_UNO]'), (N'[KillPoints]'), (N'[Deads]'),
        (N'[T1_Kills]'), (N'[T2_Kills]'), (N'[T3_Kills]'),
        (N'[T4_Kills]'), (N'[T5_Kills]'), (N'[T4&T5_KILLS]'),
        (N'[TOTAL_KILLS]'), (N'[RSS_Gathered]'), (N'[RSSAssistance]'),
        (N'[Helps]'), (N'[Alliance]'), (N'[Civilization]'),
        (N'[AOOJoined]');

    IF EXISTS
    (
        SELECT StatisticColumns FROM @ExpectedKs4StatisticColumns
        EXCEPT
        SELECT StatisticColumns
        FROM dbo.KS4_Phase2_StatisticInventory
        WHERE RunId = @RunId AND ObjectName = N'KingdomScanData4'
    )
       OR EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_StatisticInventory
        WHERE RunId = @RunId
          AND ObjectName = N'KingdomScanData4'
          AND (IsAutoCreated <> 1 OR IsUserCreated <> 0
               OR NoRecompute <> 0 OR HasFilter <> 0)
    )
        THROW 51522, 'The required 22-column KS4 statistic coverage or options drifted.', 1;

    INSERT dbo.KS4_Phase2_PermissionInventory
        (RunId, ObjectName, PrincipalName, StateCode, PermissionName, ColumnId)
    SELECT
        @RunId,
        OBJECT_NAME(permission_info.major_id),
        principal_info.name,
        permission_info.state,
        permission_info.permission_name,
        permission_info.minor_id
    FROM sys.database_permissions AS permission_info
    JOIN sys.database_principals AS principal_info
      ON principal_info.principal_id = permission_info.grantee_principal_id
    WHERE permission_info.class = 1
      AND permission_info.major_id IN
      (
          OBJECT_ID(N'dbo.KingdomScanData4'),
          OBJECT_ID(N'dbo.KingdomScanData5'),
          OBJECT_ID(N'dbo.IMPORT_STAGING')
      );

    IF (SELECT COUNT(*) FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId) <> 1
       OR NOT EXISTS
    (
        SELECT 1
        FROM dbo.KS4_Phase2_PermissionInventory
        WHERE RunId = @RunId
          AND ObjectName = N'KingdomScanData4'
          AND PrincipalName = N'ImportProcUser'
          AND StateCode = 'G'
          AND PermissionName = N'SELECT'
          AND ColumnId = 0
    )
        THROW 51523, 'Explicit table permission inventory drifted.', 1;

    DECLARE @ExpectedModules table
    (
        SchemaName sysname NOT NULL,
        ObjectName sysname NOT NULL,
        ObjectType char(2) NOT NULL,
        PRIMARY KEY (SchemaName, ObjectName)
    );

    INSERT @ExpectedModules (SchemaName, ObjectName, ObjectType)
    VALUES
        (N'dbo', N'v_Active_Players', 'V'),
        (N'dbo', N'v_GovernorNames', 'V'),
        (N'dbo', N'v_KVK_Under50_Last3_WithLatest', 'V'),
        (N'dbo', N'v_MGE_SignupReview', 'V'),
        (N'dbo', N'v_PlayerLatestStats', 'V'),
        (N'dbo', N'vDaily_Helps', 'V'),
        (N'dbo', N'vDaily_PlayerExport', 'V'),
        (N'dbo', N'vDaily_RSSAssisted', 'V'),
        (N'dbo', N'vDaily_RSSGathered', 'V'),
        (N'dbo', N'vw_Governor_KVK_Summary_GlobalLatest', 'V'),
        (N'dbo', N'vWTD_Helps', 'V'),
        (N'dbo', N'vWTD_RSSAssisted', 'V'),
        (N'dbo', N'vWTD_RSSGathered', 'V'),
        (N'dbo', N'CREATE_DELTA_TABLES', 'P'),
        (N'dbo', N'CREATE_THE_AVERAGES', 'P'),
        (N'dbo', N'DEADSSUMMARY_PROC', 'P'),
        (N'dbo', N'FIX_IMPORT_STAGING', 'P'),
        (N'dbo', N'GOVERNOR_NAMES_PROC', 'P'),
        (N'dbo', N'HEALEDSUMMARY_PROC', 'P'),
        (N'dbo', N'HEALEDSUMMARY_PROC_OPT', 'P'),
        (N'dbo', N'IMPORT_STAGING_PROC', 'P'),
        (N'dbo', N'KILLPOINTSSUMMARY_PROC', 'P'),
        (N'dbo', N'KILLSSUMMARY_PROC', 'P'),
        (N'dbo', N'KT4SUMMARY_PROC', 'P'),
        (N'dbo', N'KT5SUMMARY_PROC', 'P'),
        (N'dbo', N'POWERSUMMARY_PROC', 'P'),
        (N'dbo', N'RANGEDSUMMARY_PROC', 'P'),
        (N'dbo', N'Refresh_PlayerScanMeta', 'P'),
        (N'dbo', N'sp_ExcelOutput_ByKVK', 'P'),
        (N'dbo', N'sp_Loop_ExcelOutput_ByKVK', 'P'),
        (N'dbo', N'sp_Prep_ExcelOutputTable', 'P'),
        (N'dbo', N'sp_Prep_TargetTable', 'P'),
        (N'dbo', N'sp_Rebuild_ExcelForDashboard', 'P'),
        (N'dbo', N'sp_Rebuild_v_PlayerKVK_Last3', 'P'),
        (N'dbo', N'sp_RefreshInactiveGovernors', 'P'),
        (N'dbo', N'SP_Stats_for_Upload', 'P'),
        (N'dbo', N'sp_TARGETS_MASTER', 'P'),
        (N'dbo', N'SUMMARY_PROC', 'P'),
        (N'dbo', N'TARGETS', 'P'),
        (N'dbo', N'TARGETS_NEW', 'P'),
        (N'dbo', N'TEST', 'P'),
        (N'dbo', N'UPDATE_ALL', 'P'),
        (N'dbo', N'UPDATE_ALL2', 'P'),
        (N'dbo', N'UPDATE_RALLY_DATA', 'P'),
        (N'dbo', N'usp_BackfillKvkFinalReportCompletion', 'P'),
        (N'dbo', N'usp_GetLeadershipPlayerIdentityHistory', 'P'),
        (N'dbo', N'usp_GetLeadershipPlayerLastActive', 'P'),
        (N'dbo', N'usp_GetLeadershipPlayerLookupDirectory', 'P'),
        (N'dbo', N'usp_GetLeadershipPlayerReview', 'P'),
        (N'dbo', N'usp_GetPersonalStatsDaily', 'P'),
        (N'dbo', N'usp_LeadershipPlayerGovernorExists', 'P'),
        (N'dbo', N'usp_UpsertGovernorNameHistoryForScan', 'P');

    IF (SELECT COUNT(*) FROM @ExpectedModules) <> 52
       OR EXISTS
    (
        SELECT
            SchemaName COLLATE DATABASE_DEFAULT,
            ObjectName COLLATE DATABASE_DEFAULT,
            ObjectType COLLATE DATABASE_DEFAULT
        FROM @ExpectedModules
        EXCEPT
        SELECT
            OBJECT_SCHEMA_NAME(object_info.object_id) COLLATE DATABASE_DEFAULT,
            object_info.name COLLATE DATABASE_DEFAULT,
            object_info.type COLLATE DATABASE_DEFAULT
        FROM sys.objects AS object_info
        WHERE object_info.object_id IN
        (
            SELECT OBJECT_ID(QUOTENAME(SchemaName) + N'.' + QUOTENAME(ObjectName))
            FROM @ExpectedModules
        )
    )
        THROW 51524, 'The exact 52-module inventory is incomplete or drifted.', 1;

    INSERT dbo.KS4_Phase2_ModuleInventory
    (
        RunId, SchemaName, ObjectName, ObjectType, DefinitionHash,
        UsesAnsiNulls, UsesQuotedIdentifier
    )
    SELECT
        @RunId,
        expected.SchemaName,
        expected.ObjectName,
        expected.ObjectType,
        HASHBYTES('SHA2_256', CONVERT(varbinary(max), module_info.definition)),
        module_info.uses_ansi_nulls,
        module_info.uses_quoted_identifier
    FROM @ExpectedModules AS expected
    JOIN sys.sql_modules AS module_info
      ON module_info.object_id =
         OBJECT_ID(QUOTENAME(expected.SchemaName) + N'.' + QUOTENAME(expected.ObjectName));

    DECLARE
        @Ks4Rows bigint,
        @Ks5Rows bigint,
        @StagingRows bigint,
        @Ks4MaxScan int,
        @Ks5MaxScan int;

    SELECT @Ks4Rows = COUNT_BIG(*), @Ks4MaxScan = MAX(TRY_CONVERT(int, SCANORDER))
    FROM dbo.KingdomScanData4;
    SELECT @Ks5Rows = COUNT_BIG(*), @Ks5MaxScan = MAX(TRY_CONVERT(int, SCANORDER))
    FROM dbo.KingdomScanData5;
    SELECT @StagingRows = COUNT_BIG(*) FROM dbo.IMPORT_STAGING;

    IF DB_NAME() <> @ProductionDatabase
       AND (@Ks4Rows <> 394506 OR @Ks5Rows <> 394526
            OR @Ks4MaxScan <> 1020 OR @Ks5MaxScan <> 1020
            OR @StagingRows <> 0)
        THROW 51525, 'Representative-copy row, scan, or staging drift detected.', 1;

    DECLARE
        @ColumnInventoryText nvarchar(max),
        @IndexInventoryText nvarchar(max),
        @StatisticInventoryText nvarchar(max),
        @PermissionInventoryText nvarchar(max),
        @ModuleInventoryText nvarchar(max),
        @ColumnInventoryHash varbinary(32),
        @IndexInventoryHash varbinary(32),
        @StatisticInventoryHash varbinary(32),
        @PermissionInventoryHash varbinary(32),
        @ModuleInventoryHash varbinary(32);

    SELECT @ColumnInventoryText = STRING_AGG(
        CONVERT(nvarchar(max), CONCAT_WS(N'|', ObjectName, ColumnId, ColumnName,
            TypeName, MaxLength, [Precision], Scale, CollationName, IsNullable,
            IsIdentity, CONVERT(nvarchar(100), IdentitySeed),
            CONVERT(nvarchar(100), IdentityIncrement), IsComputed, IsPersisted,
            ComputedDefinition, DefaultName, DefaultDefinition)), NCHAR(10))
        WITHIN GROUP (ORDER BY ObjectName, ColumnId)
    FROM dbo.KS4_Phase2_ColumnInventory WHERE RunId = @RunId;

    SELECT @IndexInventoryText = STRING_AGG(
        CONVERT(nvarchar(max), CONCAT_WS(N'|', ObjectName, IndexName, TypeDesc,
            IsUnique, IsPrimaryKey, IsDisabled, HasFilter, FilterDefinition,
            KeyColumns, IncludeColumns)), NCHAR(10))
        WITHIN GROUP (ORDER BY ObjectName, IndexName)
    FROM dbo.KS4_Phase2_IndexInventory WHERE RunId = @RunId;

    SELECT @StatisticInventoryText = STRING_AGG(
        CONVERT(nvarchar(max), CONCAT_WS(N'|', ObjectName, StatisticName,
            IsAutoCreated, IsUserCreated, NoRecompute, HasFilter,
            FilterDefinition, StatisticColumns)), NCHAR(10))
        WITHIN GROUP (ORDER BY ObjectName, StatisticName)
    FROM dbo.KS4_Phase2_StatisticInventory WHERE RunId = @RunId;

    SELECT @PermissionInventoryText = STRING_AGG(
        CONVERT(nvarchar(max), CONCAT_WS(N'|', ObjectName, PrincipalName,
            StateCode, PermissionName, ColumnId)), NCHAR(10))
        WITHIN GROUP (ORDER BY ObjectName, PrincipalName, PermissionName, ColumnId)
    FROM dbo.KS4_Phase2_PermissionInventory WHERE RunId = @RunId;

    SELECT @ModuleInventoryText = STRING_AGG(
        CONVERT(nvarchar(max), CONCAT_WS(N'|', SchemaName, ObjectName,
            ObjectType, CONVERT(char(64), DefinitionHash, 2),
            UsesAnsiNulls, UsesQuotedIdentifier)), NCHAR(10))
        WITHIN GROUP (ORDER BY SchemaName, ObjectName)
    FROM dbo.KS4_Phase2_ModuleInventory WHERE RunId = @RunId;

    SET @ColumnInventoryHash = HASHBYTES('SHA2_256', COALESCE(@ColumnInventoryText, N''));
    SET @IndexInventoryHash = HASHBYTES('SHA2_256', COALESCE(@IndexInventoryText, N''));
    SET @StatisticInventoryHash = HASHBYTES('SHA2_256', COALESCE(@StatisticInventoryText, N''));
    SET @PermissionInventoryHash = HASHBYTES('SHA2_256', COALESCE(@PermissionInventoryText, N''));
    SET @ModuleInventoryHash = HASHBYTES('SHA2_256', COALESCE(@ModuleInventoryText, N''));

    DECLARE
        @VolumeFreeBytes bigint,
        @DataFreeInsideMb decimal(19, 2),
        @TempdbFreeMb decimal(19, 2),
        @LogHeadroomMb decimal(19, 2),
        @DataLogicalName sysname,
        @CurrentDataSizeMb bigint,
        @TargetDataSizeMb bigint,
        @DataPreallocationHeadroomMb bigint = 64;

    IF (SELECT COUNT(*) FROM sys.database_files WHERE type = 0) <> 1
        THROW 51526, 'The approved package requires exactly one ROWS data file; redesign preallocation for this drift before continuing.', 1;

    SELECT TOP (1)
        @VolumeFreeBytes = volume.available_bytes
    FROM sys.database_files AS file_info
    CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
    WHERE file_info.type = 0
    ORDER BY file_info.file_id;

    IF @VolumeFreeBytes < CONVERT(bigint, 20) * 1024 * 1024 * 1024
        THROW 51527, 'Less than 20 GB is free before controlled preallocation.', 1;

    SELECT
        @DataLogicalName = MIN(CASE WHEN type = 0 THEN name END),
        @CurrentDataSizeMb = CONVERT(bigint, CEILING(SUM(CASE WHEN type = 0 THEN size ELSE 0 END) * 8.0 / 1024.0)),
        @DataFreeInsideMb = SUM(CASE WHEN type = 0
            THEN size - FILEPROPERTY(name, 'SpaceUsed') ELSE 0 END) * 8.0 / 1024.0
    FROM sys.database_files;

    IF @DataFreeInsideMb < 8192
    BEGIN
        -- ALTER DATABASE can consume a small number of metadata pages while growing the file.
        -- Keep explicit headroom above the hard 8 GB post-allocation threshold so the same
        -- statement cannot leave the subsequent guard a fraction of a megabyte short.
        SET @TargetDataSizeMb =
            @CurrentDataSizeMb
            + CONVERT(bigint, CEILING(8192 - @DataFreeInsideMb))
            + @DataPreallocationHeadroomMb;
        SET @Sql =
            N'ALTER DATABASE ' + QUOTENAME(DB_NAME())
            + N' MODIFY FILE (NAME = ' + QUOTENAME(@DataLogicalName, '''')
            + N', SIZE = ' + CONVERT(nvarchar(30), @TargetDataSizeMb) + N'MB);';
        EXEC sys.sp_executesql @Sql;
    END;

    SELECT @DataFreeInsideMb =
        SUM(CASE WHEN type = 0
            THEN size - FILEPROPERTY(name, 'SpaceUsed') ELSE 0 END) * 8.0 / 1024.0
    FROM sys.database_files;

    SELECT TOP (1) @VolumeFreeBytes = volume.available_bytes
    FROM sys.database_files AS file_info
    CROSS APPLY sys.dm_os_volume_stats(DB_ID(), file_info.file_id) AS volume
    WHERE file_info.type = 0
    ORDER BY file_info.file_id;

    SELECT @TempdbFreeMb =
        SUM(unallocated_extent_page_count) * 8.0 / 1024.0
    FROM tempdb.sys.dm_db_file_space_usage;

    SELECT @LogHeadroomMb =
        (total_log_size_in_bytes - used_log_space_in_bytes) / 1048576.0
    FROM sys.dm_db_log_space_usage;

    IF @DataFreeInsideMb < 8192
       OR @VolumeFreeBytes < CONVERT(bigint, 12) * 1024 * 1024 * 1024
       OR @LogHeadroomMb < 4096
       OR @TempdbFreeMb < 1024
        THROW 51528, 'Post-preallocation data, volume, log, or tempdb capacity threshold failed.', 1;

    SET @BackupPath =
        N'C:\sql_backup\'
        + REPLACE(DB_NAME(), N']', N'')
        + N'_KS4_PHASE2_PRECHANGE_'
        + REPLACE(CONVERT(nvarchar(36), @RunId), N'-', N'')
        + N'.bak';

    BACKUP DATABASE @ConfirmTargetDatabase
    TO DISK = @BackupPath
    WITH COPY_ONLY, CHECKSUM, INIT, COMPRESSION, STATS = 10;

    RESTORE VERIFYONLY
    FROM DISK = @BackupPath
    WITH CHECKSUM;

    UPDATE dbo.KS4_Phase2_PreflightState
    SET CompletedAtUtc = SYSUTCDATETIME(),
        ExpiresAtUtc = DATEADD(hour, 4, SYSUTCDATETIME()),
        BackupPath = @BackupPath,
        BackupVerified = 1,
        Ks4Rows = @Ks4Rows,
        Ks5Rows = @Ks5Rows,
        StagingRows = @StagingRows,
        Ks4MaxScan = @Ks4MaxScan,
        Ks5MaxScan = @Ks5MaxScan,
        ColumnInventoryHash = @ColumnInventoryHash,
        IndexInventoryHash = @IndexInventoryHash,
        StatisticInventoryHash = @StatisticInventoryHash,
        PermissionInventoryHash = @PermissionInventoryHash,
        ModuleInventoryHash = @ModuleInventoryHash,
        Status = 'PASS'
    WHERE RunId = @RunId;

    SELECT
        N'phase2_preflight_completion' AS EvidenceSection,
        @ScriptRevision AS ScriptRevision,
        @RunId AS RunId,
        DB_NAME() AS DatabaseName,
        @@SERVERNAME AS ServerName,
        @Ks4Rows AS Ks4Rows,
        @Ks5Rows AS Ks5Rows,
        @StagingRows AS StagingRows,
        @Ks4MaxScan AS Ks4MaxScan,
        @Ks5MaxScan AS Ks5MaxScan,
        @DataFreeInsideMb AS DataFreeInsideMb,
        CONVERT(decimal(19, 2), @VolumeFreeBytes / 1048576.0) AS VolumeFreeMb,
        @LogHeadroomMb AS LogHeadroomMb,
        @TempdbFreeMb AS TempdbFreeMb,
        @BackupPath AS BackupPath,
        CONVERT(char(64), @ColumnInventoryHash, 2) AS ColumnInventoryHash,
        CONVERT(char(64), @IndexInventoryHash, 2) AS IndexInventoryHash,
        CONVERT(char(64), @StatisticInventoryHash, 2) AS StatisticInventoryHash,
        CONVERT(char(64), @PermissionInventoryHash, 2) AS PermissionInventoryHash,
        CONVERT(char(64), @ModuleInventoryHash, 2) AS ModuleInventoryHash,
        N'PASS' AS PreflightStatus,
        SYSUTCDATETIME() AS CompletedAtUtc;
END TRY
BEGIN CATCH
    UPDATE dbo.KS4_Phase2_PreflightState
    SET CompletedAtUtc = SYSUTCDATETIME(),
        Status = 'FAILED',
        FailureMessage = ERROR_MESSAGE()
    WHERE RunId = @RunId;
    THROW;
END CATCH;
