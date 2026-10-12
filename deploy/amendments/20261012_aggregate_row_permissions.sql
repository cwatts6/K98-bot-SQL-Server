/* Existing-account amendment; not an automatically selected schema migration.
   Requires an independently reviewed release packet and a drained application.
   Caller creates #AggregatePermissionAmendment with exactly one row:
     ExpectedServer nvarchar(128), ExpectedDatabase nvarchar(128),
     PrincipalName nvarchar(128), LoginSid varbinary(85), Action varchar(8).
   Action is Apply or Rollback. No defaults and no SQLCMD interpolation.
   See docs/AGGREGATE_ROW_PERMISSIONS_20261012.md before execution.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF @@TRANCOUNT <> 0 THROW 51500, 'Amendment requires its own transaction.', 1;
IF ISNULL(IS_SRVROLEMEMBER(N'sysadmin'), 0) <> 1
    THROW 51501, 'Amendment requires the reviewed administrative session.', 1;
IF OBJECT_ID('tempdb..#AggregatePermissionAmendment') IS NULL
    THROW 51502, 'Explicit amendment identity is required.', 1;
IF (SELECT COUNT_BIG(*) FROM #AggregatePermissionAmendment) <> 1
    THROW 51503, 'Exactly one amendment identity is required.', 1;

DECLARE @server nvarchar(128), @database nvarchar(128), @principal nvarchar(128),
        @sid varbinary(85), @action varchar(8), @user int, @lock int, @count int;
SELECT @server=ExpectedServer, @database=ExpectedDatabase,
       @principal=PrincipalName, @sid=LoginSid, @action=Action
FROM #AggregatePermissionAmendment;
IF @server IS NULL OR @database IS NULL OR @principal IS NULL OR @sid IS NULL
   OR DATALENGTH(@sid) < 16 OR @action IS NULL
   OR @action COLLATE Latin1_General_100_BIN2 NOT IN ('Apply','Rollback')
   OR @server COLLATE Latin1_General_100_BIN2 <>
      CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) COLLATE Latin1_General_100_BIN2
   OR @database COLLATE Latin1_General_100_BIN2 <> DB_NAME() COLLATE Latin1_General_100_BIN2
   OR NOT (@database COLLATE Latin1_General_100_BIN2 = N'ROK_TRACKER'
       OR @database COLLATE Latin1_General_100_BIN2 LIKE N'K98[_]Aggregate[_]Disposable[_]%')
    THROW 51504, 'Amendment target or action differs from reviewed identity.', 1;
IF @database = N'ROK_TRACKER'
   AND (@principal COLLATE Latin1_General_100_BIN2 <> N'S11_ExportApplication'
        OR SUSER_SID(@principal) IS NULL OR SUSER_SID(@principal) <> @sid)
    THROW 51505, 'Production application login identity differs.', 1;

BEGIN TRY
    BEGIN TRANSACTION;
    EXEC @lock=sys.sp_getapplock @Resource=N'K98:S11:schema', @LockMode=N'Exclusive',
        @LockOwner=N'Transaction', @LockTimeout=0;
    IF @lock < 0 THROW 51506, 'S11 deployment lock is unavailable.', 1;
    SELECT @user=principal_id FROM sys.database_principals
    WHERE name COLLATE Latin1_General_100_BIN2 = @principal COLLATE Latin1_General_100_BIN2
      AND sid=@sid AND type='S' AND principal_id > 4;
    IF @user IS NULL THROW 51507, 'Existing application database user/SID differs.', 1;
    IF OBJECT_ID(N'KVK.SourceKingdomReportRow', N'U') IS NULL
       OR OBJECT_ID(N'KVK.SourceCampReportRow', N'U') IS NULL
        THROW 51508, 'Both reviewed row tables must already exist.', 1;
    IF EXISTS (
        SELECT 1 FROM sys.database_permissions
        WHERE grantee_principal_id=@user AND class=1
          AND major_id IN (OBJECT_ID(N'KVK.SourceKingdomReportRow'),OBJECT_ID(N'KVK.SourceCampReportRow'))
          AND (minor_id<>0 OR state<>'G' OR permission_name NOT IN ('INSERT','SELECT'))
    ) THROW 51509, 'Unexpected row-table grant, deny, column right or grant option.', 1;
    SELECT @count=COUNT(*) FROM sys.database_permissions
    WHERE grantee_principal_id=@user AND class=1
      AND major_id IN (OBJECT_ID(N'KVK.SourceKingdomReportRow'),OBJECT_ID(N'KVK.SourceCampReportRow'));
    IF @count NOT IN (0,4) THROW 51510, 'Partial row-table amendment requires investigation.', 1;

    DECLARE @sql nvarchar(max);
    IF @action='Apply' AND @count=0
    BEGIN
        SET @sql=N'GRANT INSERT, SELECT ON OBJECT::KVK.SourceKingdomReportRow TO '+QUOTENAME(@principal)+N';'
                +N'GRANT INSERT, SELECT ON OBJECT::KVK.SourceCampReportRow TO '+QUOTENAME(@principal)+N';';
        EXEC sys.sp_executesql @sql;
    END;
    IF @action='Rollback' AND @count=4
    BEGIN
        SET @sql=N'REVOKE INSERT, SELECT ON OBJECT::KVK.SourceKingdomReportRow FROM '+QUOTENAME(@principal)+N';'
                +N'REVOKE INSERT, SELECT ON OBJECT::KVK.SourceCampReportRow FROM '+QUOTENAME(@principal)+N';';
        EXEC sys.sp_executesql @sql;
    END;
    SELECT @count=COUNT(*) FROM sys.database_permissions
    WHERE grantee_principal_id=@user AND class=1 AND minor_id=0 AND state='G'
      AND permission_name IN ('INSERT','SELECT')
      AND major_id IN (OBJECT_ID(N'KVK.SourceKingdomReportRow'),OBJECT_ID(N'KVK.SourceCampReportRow'));
    IF @count <> CASE WHEN @action='Apply' THEN 4 ELSE 0 END
        THROW 51511, 'Amendment postcondition failed.', 1;
    COMMIT TRANSACTION;
    SELECT @server AS ServerName,@database AS DatabaseName,@principal AS PrincipalName,
           LOWER(CONVERT(varchar(170),@sid,2)) AS LoginSid,@action AS Action,@count AS DirectRowGrants;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
