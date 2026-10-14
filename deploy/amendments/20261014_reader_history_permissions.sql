/* Explicit existing-account amendment. Caller supplies exactly one row in
   #ReaderHistoryPermissionAmendment(ExpectedServer nvarchar(128),
   ExpectedDatabase nvarchar(128), PrincipalName nvarchar(128),
   LoginSid varbinary(85), Action varchar(8)). Apply or Rollback only.
   Requires the reviewed protected-contract release and drained application.
   No schema, business-data, role, ownership or migration-history changes. */
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51520, 'Own transaction required.', 1;
IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'),0)<>1 THROW 51521, 'Reviewed administrator required.', 1;
IF OBJECT_ID('tempdb..#ReaderHistoryPermissionAmendment') IS NULL
    THROW 51522, 'Explicit reviewed identity required.', 1;
IF (SELECT COUNT_BIG(*) FROM #ReaderHistoryPermissionAmendment)<>1
    THROW 51523, 'Exactly one identity required.', 1;
DECLARE @server nvarchar(128),@database nvarchar(128),@principal nvarchar(128),
        @sid varbinary(85),@action varchar(8),@user int,@lock int,@count int;
SELECT @server=ExpectedServer,@database=ExpectedDatabase,@principal=PrincipalName,
       @sid=LoginSid,@action=Action FROM #ReaderHistoryPermissionAmendment;
IF @server IS NULL OR @database IS NULL OR @principal IS NULL OR @sid IS NULL
   OR DATALENGTH(@sid)<16 OR @action IS NULL
   OR @action COLLATE Latin1_General_100_BIN2 NOT IN ('Apply','Rollback')
   OR @server COLLATE Latin1_General_100_BIN2 <>
      CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
   OR @database COLLATE Latin1_General_100_BIN2 <> DB_NAME() COLLATE Latin1_General_100_BIN2
   OR NOT (@database COLLATE Latin1_General_100_BIN2=N'ROK_TRACKER'
       OR @database COLLATE Latin1_General_100_BIN2=N'K98_ReaderActivation_Disposable_20261014')
    THROW 51524, 'Target or action differs from reviewed identity.', 1;
IF @database=N'ROK_TRACKER' AND
   (@principal COLLATE Latin1_General_100_BIN2<>N'S11_ExportApplication'
    OR SUSER_SID(@principal) IS NULL OR SUSER_SID(@principal)<>@sid)
    THROW 51525, 'Production login identity differs.', 1;
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode=N'Exclusive',
         @LockOwner=N'Transaction',@LockTimeout=0;
    IF @lock<0 THROW 51526, 'Deployment lock unavailable.', 1;
    SELECT @user=principal_id FROM sys.database_principals
    WHERE name COLLATE Latin1_General_100_BIN2=@principal COLLATE Latin1_General_100_BIN2
      AND sid=@sid AND type='S' AND principal_id>4;
    IF @user IS NULL THROW 51527, 'Database principal/SID differs.', 1;
    IF OBJECT_ID(N'KVK.SourceExportHistory',N'U') IS NULL
       OR OBJECT_ID(N'KVK.SourceExportHistoryRow',N'U') IS NULL
       OR COL_LENGTH(N'KVK.SourceExportHistory',N'AttemptCount') IS NULL
       OR COL_LENGTH(N'KVK.SourceExportHistory',N'ContentHash') IS NULL
        THROW 51528, 'Installed history tables required.', 1;
    DECLARE @expected TABLE (major_id int,minor_id int,permission_name nvarchar(128));
    INSERT @expected VALUES
        (OBJECT_ID(N'KVK.SourceExportHistory'),0,N'SELECT'),
        (OBJECT_ID(N'KVK.SourceExportHistory'),0,N'INSERT'),
        (OBJECT_ID(N'KVK.SourceExportHistoryRow'),0,N'SELECT'),
        (OBJECT_ID(N'KVK.SourceExportHistoryRow'),0,N'INSERT'),
        (OBJECT_ID(N'KVK.SourceExportHistory'),COLUMNPROPERTY(OBJECT_ID(N'KVK.SourceExportHistory'),N'AttemptCount','ColumnId'),N'UPDATE'),
        (OBJECT_ID(N'KVK.SourceExportHistory'),COLUMNPROPERTY(OBJECT_ID(N'KVK.SourceExportHistory'),N'ContentHash','ColumnId'),N'UPDATE');
    IF EXISTS (SELECT 1 FROM sys.database_permissions p
        WHERE p.grantee_principal_id=@user AND p.class=1
          AND p.major_id IN (OBJECT_ID(N'KVK.SourceExportHistory'),OBJECT_ID(N'KVK.SourceExportHistoryRow'))
          AND (p.state<>'G' OR NOT EXISTS (SELECT 1 FROM @expected e
              WHERE e.major_id=p.major_id AND e.minor_id=p.minor_id AND e.permission_name COLLATE Latin1_General_100_BIN2=p.permission_name COLLATE Latin1_General_100_BIN2)))
        THROW 51529, 'Unexpected history permissions.', 1;
    SELECT @count=COUNT(*) FROM sys.database_permissions p JOIN @expected e
      ON e.major_id=p.major_id AND e.minor_id=p.minor_id AND e.permission_name COLLATE Latin1_General_100_BIN2=p.permission_name COLLATE Latin1_General_100_BIN2
      WHERE p.grantee_principal_id=@user AND p.class=1 AND p.state='G';
    IF @count NOT IN (0,6) THROW 51530, 'Partial amendment requires investigation.', 1;
    DECLARE @sql nvarchar(max);
    IF @action='Apply' AND @count=0
    BEGIN
        SET @sql=N'GRANT SELECT, INSERT ON OBJECT::KVK.SourceExportHistory TO '+QUOTENAME(@principal)+N';'
            +N'GRANT UPDATE ON OBJECT::KVK.SourceExportHistory (AttemptCount,ContentHash) TO '+QUOTENAME(@principal)+N';'
            +N'GRANT SELECT, INSERT ON OBJECT::KVK.SourceExportHistoryRow TO '+QUOTENAME(@principal)+N';';
        EXEC sys.sp_executesql @sql;
    END;
    IF @action='Rollback' AND @count=6
    BEGIN
        SET @sql=N'REVOKE SELECT, INSERT ON OBJECT::KVK.SourceExportHistory FROM '+QUOTENAME(@principal)+N';'
            +N'REVOKE UPDATE ON OBJECT::KVK.SourceExportHistory (AttemptCount,ContentHash) FROM '+QUOTENAME(@principal)+N';'
            +N'REVOKE SELECT, INSERT ON OBJECT::KVK.SourceExportHistoryRow FROM '+QUOTENAME(@principal)+N';';
        EXEC sys.sp_executesql @sql;
    END;
    SELECT @count=COUNT(*) FROM sys.database_permissions p JOIN @expected e
      ON e.major_id=p.major_id AND e.minor_id=p.minor_id AND e.permission_name COLLATE Latin1_General_100_BIN2=p.permission_name COLLATE Latin1_General_100_BIN2
      WHERE p.grantee_principal_id=@user AND p.class=1 AND p.state='G';
    IF @count<>CASE WHEN @action='Apply' THEN 6 ELSE 0 END
        THROW 51531, 'Permission postcondition failed.', 1;
    COMMIT;
    SELECT @server AS ServerName,@database AS DatabaseName,@principal AS PrincipalName,
        LOWER(CONVERT(varchar(170),@sid,2)) AS LoginSid,@action AS Action,@count AS DirectHistoryGrants;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK;
    THROW;
END CATCH;
