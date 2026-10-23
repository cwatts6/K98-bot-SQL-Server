from pathlib import Path
import hashlib
import re
import subprocess

root = Path(__file__).resolve().parents[1]
schema = root / 'sql_schema'
name = '20261023_001_legacy_export_closeout'
new = ['dbo.ExportLegacyCloseout.Table.sql', 'dbo.ExportActiveContainedTarget.View.sql', 'dbo.usp_ExportLegacyCloseout.StoredProcedure.sql']
changed = ['dbo.usp_ExportExecutionStreamTransition.StoredProcedure.sql', 'dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql', 'dbo.usp_ExportReconciliationProofIssue.StoredProcedure.sql']
def body(raw):
    return raw[raw.index('CREATE '):].strip().removesuffix('GO').strip().replace('\r\n','\n')
def sha(text):
    return hashlib.sha256(text.encode('utf-16le')).hexdigest()
def quote(text):
    return "N'"+text.replace("'", "''")+"'"
parts = [f'''/*
MigrationId: {name}
Purpose: Allow verified legacy closeout without replacing spreadsheet URLs
Author: cwatts
CreatedUtc: 2026-10-23
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact module preimages and closed protected authority
PostValidationQuery: Exact definitions and authority-only closeout permission
*/
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51740,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int,@Body nvarchar(max);
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51740,'Schema busy.',1;
IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH(HOLDLOCK) WHERE State<>'closed')
 THROW 51740,'Authority sessions must be closed.',1;
''']
for file in changed:
    obj = file.removesuffix('.StoredProcedure.sql')
    old = body(subprocess.check_output(['git','-C',str(root),'show','d2f1bd746d1c1c6b24998b7a3c5e600e581682e6:sql_schema/'+file]).decode('utf-8-sig'))
    after = body((schema/file).read_text(encoding='utf-8-sig'))
    parts.append(f"""SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'{obj}'));
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE') WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE') WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE') ELSE @Body END;
IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body) NOT IN(0x{sha(old)},0x{sha(after)})
 THROW 51740,'Unreviewed {obj} preimage.',1;
IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'{obj}'))
 OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'{obj}') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
 THROW 51740,'Unexpected execution context or signature.',1;
""")
table = (schema/new[0]).read_text()
parts.append("IF OBJECT_ID(N'dbo.ExportLegacyCloseout') IS NULL EXEC sys.sp_executesql "+quote(table)+";\n")
# Reference table comparison verifies an existing installation without changing it.
reference = re.sub(r'\bCONSTRAINT\s+\w+\s+', '', table)
reference = '\n'.join(line for line in reference.splitlines() if 'FOREIGN KEY' not in line)
reference = reference.replace('dbo.ExportLegacyCloseout','#ExpectedLegacyCloseout')
reference = re.sub(r',\s*\);', '\n);', reference)
parts.append(reference+'\n')
cols='column_id,name COLLATE Latin1_General_100_BIN2 AS name,system_type_id,max_length,precision,scale,collation_name COLLATE Latin1_General_100_BIN2 AS collation_name,is_nullable,is_identity,is_computed'
parts.append(f"""IF EXISTS(SELECT {cols} FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') EXCEPT SELECT {cols} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout'))
 OR EXISTS(SELECT {cols} FROM tempdb.sys.columns WHERE object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout') EXCEPT SELECT {cols} FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 THROW 51740,'Existing closeout table differs.',1;
IF EXISTS(SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout')
 EXCEPT SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout'))
 OR EXISTS(SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM tempdb.sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'tempdb..#ExpectedLegacyCloseout')
 EXCEPT SELECT definition COLLATE Latin1_General_100_BIN2,is_disabled,is_not_trusted FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR (SELECT COUNT(*) FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 THROW 51740,'Existing closeout checks differ.',1;
DROP TABLE #ExpectedLegacyCloseout;
IF (SELECT COUNT(*) FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 OR NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id
  WHERE i.object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND i.name=N'PK_ExportLegacyCloseout'
   AND i.is_primary_key=1 AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
   AND c.key_ordinal=1 AND COL_NAME(c.object_id,c.column_id)=N'ActionID'
   AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=i.object_id AND x.index_id=i.index_id)=1)
 OR NOT EXISTS(SELECT 1 FROM sys.indexes i JOIN sys.index_columns c ON c.object_id=i.object_id AND c.index_id=i.index_id
  WHERE i.object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND i.name=N'UQ_ExportLegacyCloseout_Job'
   AND i.is_unique_constraint=1 AND i.is_unique=1 AND i.is_disabled=0 AND i.has_filter=0
   AND c.key_ordinal=1 AND COL_NAME(c.object_id,c.column_id)=N'JobID'
   AND (SELECT COUNT(*) FROM sys.index_columns x WHERE x.object_id=i.object_id AND x.index_id=i.index_id AND x.key_ordinal>0)=1)
 THROW 51740,'Existing closeout keys differ.',1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))<>2
 OR EXISTS(SELECT 1 FROM sys.foreign_keys f WHERE f.parent_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND
  (f.is_disabled=1 OR f.is_not_trusted=1 OR f.delete_referential_action<>0 OR f.update_referential_action<>0
   OR (SELECT COUNT(*) FROM sys.foreign_key_columns c WHERE c.constraint_object_id=f.object_id)<>1
   OR NOT EXISTS(SELECT 1 FROM sys.foreign_key_columns c WHERE c.constraint_object_id=f.object_id AND
    ((f.name=N'FK_ExportLegacyCloseout_Job' AND COL_NAME(c.parent_object_id,c.parent_column_id)=N'JobID'
      AND c.referenced_object_id=OBJECT_ID(N'dbo.ExportJob') AND COL_NAME(c.referenced_object_id,c.referenced_column_id)=N'JobID')
     OR (f.name=N'FK_ExportLegacyCloseout_Containment' AND COL_NAME(c.parent_object_id,c.parent_column_id)=N'ContainmentID'
      AND c.referenced_object_id=OBJECT_ID(N'dbo.ExportTargetContainment') AND COL_NAME(c.referenced_object_id,c.referenced_column_id)=N'ContainmentID')))))
 THROW 51740,'Existing closeout references differ.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR EXISTS(SELECT 1 FROM sys.security_predicates WHERE target_object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout'))
 OR EXISTS(SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND (user_type_id<>system_type_id OR encryption_type IS NOT NULL))
 OR EXISTS(SELECT 1 FROM sys.masked_columns WHERE object_id=OBJECT_ID(N'dbo.ExportLegacyCloseout') AND is_masked=1)
 THROW 51740,'Unsupported closeout security contract.',1;
""")
for file in new[1:]+changed:
    text = body((schema/file).read_text(encoding='utf-8-sig'))
    obj = file.rsplit('.',2)[0]
    if file in new:
        parts.append(f"""IF OBJECT_ID(N'{obj}') IS NOT NULL
BEGIN
 SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'{obj}'));
 SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
 SET @Body=REPLACE(@Body,N'CREATE OR ALTER ',N'CREATE ');
 IF @Body IS NULL OR HASHBYTES('SHA2_256',@Body)<>0x{sha(text)} THROW 51740,'Existing {obj} differs.',1;
 IF EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=OBJECT_ID(N'{obj}'))
  OR EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=OBJECT_ID(N'{obj}') AND (execute_as_principal_id IS NOT NULL OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1))
  THROW 51740,'Unexpected new module security context.',1;
END;
""")
    if file in new:
        parts.append(f"IF OBJECT_ID(N'{obj}') IS NULL EXEC sys.sp_executesql "+quote(text)+';\n')
    else:
        parts.append('EXEC sys.sp_executesql '+quote(text.replace('CREATE ', 'ALTER ',1))+';\n')
parts.append('''GRANT SELECT ON dbo.ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
GRANT SELECT ON dbo.ExportActiveContainedTarget TO ExportExecutionAuthority,ExportExecutionReader;
DENY INSERT,UPDATE,DELETE,ALTER,TAKE OWNERSHIP ON dbo.ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
DENY INSERT,UPDATE,DELETE,ALTER,TAKE OWNERSHIP ON dbo.ExportActiveContainedTarget TO ExportExecutionAuthority,ExportExecutionReader;
GRANT EXECUTE ON dbo.usp_ExportLegacyCloseout TO ExportExecutionAuthority;
DENY EXECUTE ON dbo.usp_ExportLegacyCloseout TO ExportExecutionReader;
DENY ALTER,TAKE OWNERSHIP ON dbo.usp_ExportLegacyCloseout TO ExportExecutionAuthority,ExportExecutionReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
''')
(root/'migrations'/f'{name}.sql').write_text('\n'.join(parts),encoding='utf-8',newline='\n')
print('Built', name)
