/*
MigrationId: 20261010_003_stats_import_outcome_postimages
Purpose: Restore reviewed LF postimages after the Windows SQL batch loader added CR
Author: cwatts
CreatedUtc: 2026-10-10
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
TransactionMode: Auto
DataChange: No
*/
-- Exact two-object repair; no original migration replay, business execution,
-- permission change, receipt rewrite or change to the sealed R4 expectations.
-- LF postimages derive from reviewed migration 20261010_002, not live hashes.
-- CRLF preimages derive solely by expanding those exact LF line terminators.
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET LOCK_TIMEOUT 1000;
IF DB_NAME() COLLATE Latin1_General_100_BIN2 <> N'ROK_TRACKER'
    THROW 51960, 'ROK_TRACKER required.', 1;
IF @@TRANCOUNT <> 0 THROW 51960, 'Own repair transaction required.', 1;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @Lock int;
    EXEC @Lock = sys.sp_getapplock @Resource=N'K98:S11:schema', @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=0;
    IF @Lock < 0 THROW 51960, 'Schema busy.', 1;
    IF (SELECT COUNT(*) FROM dbo.SchemaMigrationHistory WHERE
        (MigrationId=N'20261009_001_stats_import_outcomes' AND Status=N'Failed' AND LOWER(ChecksumSha256) COLLATE Latin1_General_100_BIN2=N'344f050165a7f64078615db9deac10a687babdc1c28c2536eaedcda07fae87f3') OR
        (MigrationId=N'20261010_001_stats_import_outcomes_collation' AND Status=N'Failed' AND LOWER(ChecksumSha256) COLLATE Latin1_General_100_BIN2=N'e423e79fd13234b91b62336ab8e34ff2b018b2bffcdfb3cd53dec1a9342ef315') OR
        (MigrationId=N'20261010_002_stats_import_outcomes_encoding' AND Status=N'Applied' AND LOWER(ChecksumSha256) COLLATE Latin1_General_100_BIN2=N'3792c37de9642cdb33579a4afec820f9d21a4eb14e8388281f3c40eed01c5aa9')) <> 3
        THROW 51960, 'Exact Failed/Failed/Applied predecessor lineage required; preserve receipts.', 1;
    IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WHERE State<>'closed')
        THROW 51960, 'Execution sessions must be closed.', 1;
    IF OBJECT_ID(N'dbo.StatsImportExecution',N'U') IS NULL
        THROW 51960, 'Installed outcome receipt table required.', 1;
    IF EXISTS(SELECT 1 FROM dbo.StatsImportExecution)
        THROW 51960, 'Outcome execution already occurred; reconcile before repair.', 1;

    DECLARE @Expected table(ObjectName nvarchar(128) COLLATE Latin1_General_100_BIN2 PRIMARY KEY, ObjectID int, LfHash binary(32), CrLfHash binary(32), LfBytes int, CrLfBytes int);
    INSERT @Expected VALUES
      (N'dbo.UPDATE_ALL2', OBJECT_ID(N'dbo.UPDATE_ALL2',N'P'), 0x4a5640dbdf811d645ba9ed83062f08408f5d02e6c9c2338585042b031af080bc, 0x2f68735cea47d1724efeeefc9615689630a71f0c1c7217d161ec22e6506e1d0a,91632,93646),
      (N'dbo.usp_S11RunStatsImport', OBJECT_ID(N'dbo.usp_S11RunStatsImport',N'P'), 0x034ca049c92a8b8ea654edca21f03269afae4884d398ea7d26e7ab0aade0b81e, 0x91549e165637b67698afe16038d06193e9579666875d5918ee79ccc74434bbfa,5794,5884);
    -- Validate BOTH bodies and settings before altering either. No arbitrary
    -- whitespace normalization or acceptance of an observed definition occurs.
    IF EXISTS(SELECT 1 FROM @Expected e LEFT JOIN sys.sql_modules m ON m.object_id=e.ObjectID
        WHERE e.ObjectID IS NULL OR m.definition IS NULL OR m.uses_ansi_nulls<>1 OR m.uses_quoted_identifier<>1 OR m.execute_as_principal_id IS NOT NULL
          OR NOT ((HASHBYTES('SHA2_256',m.definition)=e.LfHash AND DATALENGTH(m.definition)=e.LfBytes)
               OR (HASHBYTES('SHA2_256',m.definition)=e.CrLfHash AND DATALENGTH(m.definition)=e.CrLfBytes))
          OR HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10)))<>e.LfHash)
        THROW 51960, 'Postimage repair refused: procedure body or SET context differs from exact reviewed LF/CRLF forms.', 1;
    IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE major_id IN(SELECT ObjectID FROM @Expected))
        THROW 51960, 'Signed module requires separate reviewed signature handling.', 1;
    DECLARE @Owners table(ObjectID int, PrincipalID int NULL, SchemaID int);
    INSERT @Owners SELECT object_id,principal_id,schema_id FROM sys.objects WHERE object_id IN(SELECT ObjectID FROM @Expected);
    DECLARE @Permissions table(Class int, MajorID int, MinorID int, Grantee int, Grantor int, PermissionType int, PermissionState int);
    INSERT @Permissions SELECT class,major_id,minor_id,grantee_principal_id,grantor_principal_id,CONVERT(int,CONVERT(binary(4),type)),ASCII(state)
        FROM sys.database_permissions WHERE major_id IN(SELECT ObjectID FROM @Expected);

    DECLARE @Name nvarchar(128), @Body nvarchar(max), @Ddl nvarchar(max), @Changed int=0;
    DECLARE bodies CURSOR LOCAL FAST_FORWARD FOR SELECT ObjectName FROM @Expected ORDER BY ObjectName;
    OPEN bodies;
    FETCH NEXT FROM bodies INTO @Name;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SET @Body=OBJECT_DEFINITION(OBJECT_ID(@Name));
        IF NOT EXISTS(SELECT 1 FROM @Expected WHERE ObjectName=@Name
            AND ((HASHBYTES('SHA2_256',@Body)=LfHash AND DATALENGTH(@Body)=LfBytes)
              OR (HASHBYTES('SHA2_256',@Body)=CrLfHash AND DATALENGTH(@Body)=CrLfBytes)))
            THROW 51960, 'Module changed after validation; rolling back.', 1;
        IF CHARINDEX(NCHAR(13),@Body)>0
        BEGIN
            SET @Body=REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10));
            SET @Ddl=STUFF(@Body,1,6,N'ALTER');
            EXEC sys.sp_executesql @Ddl;
            SET @Changed+=1;
        END;
        FETCH NEXT FROM bodies INTO @Name;
    END;
    CLOSE bodies;
    DEALLOCATE bodies;

    IF EXISTS(SELECT 1 FROM @Expected e LEFT JOIN sys.sql_modules m ON m.object_id=e.ObjectID
        WHERE m.definition IS NULL OR HASHBYTES('SHA2_256',m.definition)<>e.LfHash OR DATALENGTH(m.definition)<>e.LfBytes
           OR m.uses_ansi_nulls<>1 OR m.uses_quoted_identifier<>1 OR m.execute_as_principal_id IS NOT NULL)
        THROW 51960, 'Exact LF postcondition failed; both procedure alterations will roll back.', 1;
    IF EXISTS(SELECT ObjectID,PrincipalID,SchemaID FROM @Owners EXCEPT SELECT object_id,principal_id,schema_id FROM sys.objects WHERE object_id IN(SELECT ObjectID FROM @Expected))
        THROW 51960, 'Module identity or ownership changed; rolling back.', 1;
    IF EXISTS(SELECT * FROM @Permissions EXCEPT SELECT class,major_id,minor_id,grantee_principal_id,grantor_principal_id,CONVERT(int,CONVERT(binary(4),type)),ASCII(state) FROM sys.database_permissions WHERE major_id IN(SELECT ObjectID FROM @Expected))
       OR EXISTS(SELECT class,major_id,minor_id,grantee_principal_id,grantor_principal_id,CONVERT(int,CONVERT(binary(4),type)),ASCII(state) FROM sys.database_permissions WHERE major_id IN(SELECT ObjectID FROM @Expected) EXCEPT SELECT * FROM @Permissions)
        THROW 51960, 'Module permissions changed; rolling back.', 1;
    COMMIT;
    SELECT N'POSTIMAGES_VERIFIED' AS Status,@Changed AS ChangedProcedures,CAST(0 AS bit) AS BusinessWorkExecuted;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
