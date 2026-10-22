"""Build the finite P0 receipt migration from reviewed source and a fixed base.

This generator does not connect to SQL or adopt observed definitions as expected
values. Run from any directory after reviewing changes to the source definitions.
"""

import hashlib
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "716c74ebbced800de8243892a7bce6a5ebac380c"
MIGRATION = "20261022_001_p0_pipeline_receipts"
TABLES = (
    "StatsImportReportContinuation",
    "ProcessingPipelineRun",
    "ProcessingPipelineStage",
    "ExportContainmentAttestation",
    "ExportRegistrationAttestation",
    "ExportUnownedHoldDisposition",
)
MODULES = (
    "usp_S11ValidateStatsReportStage",
    "usp_S11CompleteStatsReportsCore",
    "usp_S11CompleteStatsReports",
    "UPDATE_ALL2",
    "usp_update_stats",
)
FOREIGN_KEYS = {
    "StatsImportReportContinuation": ("PreparationID", "StatsImportExecution", "PreparationID"),
    "ProcessingPipelineStage": ("RunID", "ProcessingPipelineRun", "RunID"),
    "ExportContainmentAttestation": ("ContainmentID", "ExportTargetContainment", "ContainmentID"),
    "ExportRegistrationAttestation": (
        "ActivationID",
        "ExportReplacementActivation",
        "ActivationID",
    ),
}


def quoted(value):
    return "N'" + value.replace("'", "''") + "'"


def module_body(text):
    found = re.search(r"(?im)^(?:CREATE OR ALTER|CREATE|ALTER) PROCEDURE\b", text)
    if not found:
        raise ValueError("Procedure declaration required")
    return re.split(r"(?im)^GO\s*$", text[found.start() :])[0].strip()


def canonical(body):
    return re.sub(r"^(?:CREATE OR ALTER|CREATE  |ALTER) PROCEDURE", "CREATE PROCEDURE", body)


def module_install(name):
    path = f"sql_schema/dbo.{name}.StoredProcedure.sql"
    current = module_body((ROOT / path).read_text(encoding="utf-8-sig"))
    hashes = {hashlib.sha256(canonical(current).encode("utf-16le")).hexdigest()}
    result = subprocess.run(["git", "show", BASE + ":" + path], cwd=ROOT, capture_output=True)
    existed = result.returncode == 0
    if existed:
        prior = module_body(result.stdout.decode("utf-8-sig"))
        hashes.add(hashlib.sha256(canonical(prior).encode("utf-16le")).hexdigest())
        if name == "usp_update_stats":
            # Exact historical deployment spelling, independently compared to
            # the retained reviewed application metadata. No body normalization.
            assert prior.startswith("ALTER PROCEDURE [dbo].[usp_update_stats]")
            historical = prior.replace(
                "ALTER PROCEDURE [dbo].[usp_update_stats]", "CREATE   PROC dbo.usp_update_stats", 1
            )
            hashes.add(hashlib.sha256(historical.encode("utf-16le")).hexdigest())
    elif name not in MODULES[:3]:
        raise ValueError("Missing fixed baseline procedure")
    owner = "-2" if name == "usp_update_stats" else "NULL"
    owner_check = (
        "execute_as_principal_id<>-2 OR execute_as_principal_id IS NULL"
        if owner == "-2"
        else "execute_as_principal_id IS NOT NULL"
    )
    body = re.sub(
        r"^(?:CREATE OR ALTER|CREATE|ALTER) PROCEDURE", "CREATE OR ALTER PROCEDURE", current
    )
    return f"""
SET @Object=OBJECT_ID(N'dbo.{name}');
SET @Body=(SELECT definition FROM sys.sql_modules WHERE object_id=@Object);
IF (@Object IS NOT NULL AND (@Body IS NULL OR OBJECTPROPERTY(@Object,'IsProcedure')<>1))
    {'OR @Object IS NULL' if existed else ''}
 THROW 51961,'Missing or incompatible {name} definition.',1;
SET @Body=TRIM(N' '+NCHAR(9)+NCHAR(10)+NCHAR(13) FROM REPLACE(@Body,NCHAR(13)+NCHAR(10),NCHAR(10)));
SET @Body=CASE
 WHEN LEFT(@Body,25)=N'CREATE OR ALTER PROCEDURE' THEN STUFF(@Body,1,25,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,18)=N'CREATE   PROCEDURE' THEN STUFF(@Body,1,18,N'CREATE PROCEDURE')
 WHEN LEFT(@Body,15)=N'ALTER PROCEDURE' THEN STUFF(@Body,1,15,N'CREATE PROCEDURE')
 ELSE @Body END;
IF @Body IS NOT NULL AND HASHBYTES('SHA2_256',@Body) NOT IN ({','.join('0x'+h for h in sorted(hashes))})
 THROW 51961,'Unreviewed {name} preimage; preserve and review.',1;
IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE object_id=@Object
 AND ({owner_check} OR uses_ansi_nulls<>1 OR uses_quoted_identifier<>1 OR is_schema_bound=1))
 OR EXISTS(SELECT 1 FROM sys.crypt_properties WHERE class=1 AND major_id=@Object)
 THROW 51961,'Unexpected {name} execution context or signature.',1;
EXEC sys.sp_executesql {quoted(body)};
"""


def table_install(name):
    source = (ROOT / f"sql_schema/dbo.{name}.Table.sql").read_text(encoding="utf-8-sig")
    expected = re.sub(r"^.*CONSTRAINT \w+ FOREIGN KEY.*\n", "", source, flags=re.M)
    expected = re.sub(r"CONSTRAINT \w+ ", "", expected).replace("dbo." + name, "#Expected")
    # SQL temporary character columns otherwise inherit tempdb's collation.
    expected = re.sub(
        r"((?:n?varchar|n?char)\((?:\d+|max)\)) (?!COLLATE)",
        r"\1 COLLATE DATABASE_DEFAULT ",
        expected,
    )
    foreign = FOREIGN_KEYS.get(name)
    fk = "IF EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=@Object) THROW 51961,'Unexpected foreign key.',1;"
    if foreign:
        column, target, referenced = foreign
        fk = f"""
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=@Object)<>1
 OR NOT EXISTS(SELECT 1 FROM sys.foreign_keys f JOIN sys.foreign_key_columns c ON c.constraint_object_id=f.object_id
 WHERE f.parent_object_id=@Object AND f.referenced_object_id=OBJECT_ID(N'dbo.{target}')
 AND COL_NAME(@Object,c.parent_column_id)=N'{column}' AND COL_NAME(f.referenced_object_id,c.referenced_column_id)=N'{referenced}'
 AND f.is_disabled=0 AND f.is_not_trusted=0 AND f.is_not_for_replication=0
 AND f.delete_referential_action=0 AND f.update_referential_action=0)
 OR (SELECT COUNT(*) FROM sys.foreign_key_columns WHERE parent_object_id=@Object)<>1
 THROW 51961,'{name} foreign-key contract differs.',1;
"""
    queries = {
        "Columns": (
            "name,column_id,system_type_id,user_type_id,max_length,precision,scale,is_nullable,collation_name,is_identity,is_computed,is_rowguidcol,is_sparse,generated_always_type",
            "columns",
            "object_id",
        ),
        "Checks": (
            "definition,is_disabled,is_not_trusted,is_not_for_replication",
            "check_constraints",
            "parent_object_id",
        ),
    }
    checks = ""
    for kind, (columns, table, key) in queries.items():
        columns = ",".join(
            (
                field + " COLLATE Latin1_General_100_BIN2 AS " + field
                if field in {"name", "definition", "collation_name"}
                else field
            )
            for field in columns.split(",")
        )
        checks += f"""
SELECT {columns} INTO #Actual{kind} FROM sys.{table} WHERE {key}=@Object;
SELECT {columns} INTO #Expected{kind} FROM tempdb.sys.{table} WHERE {key}=@Expected;
IF EXISTS(SELECT * FROM #Actual{kind} EXCEPT SELECT * FROM #Expected{kind})
 OR EXISTS(SELECT * FROM #Expected{kind} EXCEPT SELECT * FROM #Actual{kind})
 OR (SELECT COUNT(*) FROM #Actual{kind})<>(SELECT COUNT(*) FROM #Expected{kind})
 THROW 51961,'{name} {kind} contract differs.',1;
DROP TABLE #Actual{kind},#Expected{kind};
"""
    checks += f"""
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ActualDefaults FROM sys.default_constraints d JOIN sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Object;
SELECT c.name COLLATE Latin1_General_100_BIN2 AS name,d.definition COLLATE Latin1_General_100_BIN2 AS definition INTO #ExpectedDefaults FROM tempdb.sys.default_constraints d JOIN tempdb.sys.columns c
 ON c.object_id=d.parent_object_id AND c.column_id=d.parent_column_id WHERE d.parent_object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualDefaults EXCEPT SELECT * FROM #ExpectedDefaults)
 OR EXISTS(SELECT * FROM #ExpectedDefaults EXCEPT SELECT * FROM #ActualDefaults)
 THROW 51961,'{name} defaults differ.',1;
DROP TABLE #ActualDefaults,#ExpectedDefaults;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ActualIndexes FROM sys.indexes i JOIN sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Object;
SELECT i.type,i.is_unique,i.is_primary_key,i.is_unique_constraint,i.is_disabled,i.has_filter,i.ignore_dup_key,
 c.name COLLATE Latin1_General_100_BIN2 AS name,ic.key_ordinal,ic.is_descending_key,ic.is_included_column
 INTO #ExpectedIndexes FROM tempdb.sys.indexes i JOIN tempdb.sys.index_columns ic ON ic.object_id=i.object_id AND ic.index_id=i.index_id
 JOIN tempdb.sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE i.object_id=@Expected;
IF EXISTS(SELECT * FROM #ActualIndexes EXCEPT SELECT * FROM #ExpectedIndexes)
 OR EXISTS(SELECT * FROM #ExpectedIndexes EXCEPT SELECT * FROM #ActualIndexes)
 OR (SELECT COUNT(*) FROM sys.indexes WHERE object_id=@Object)<>(SELECT COUNT(*) FROM tempdb.sys.indexes WHERE object_id=@Expected)
 OR (SELECT COUNT(*) FROM #ActualIndexes)<>(SELECT COUNT(*) FROM #ExpectedIndexes)
 THROW 51961,'{name} index contract differs.',1;
DROP TABLE #ActualIndexes,#ExpectedIndexes;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id=@Object)
 OR EXISTS(SELECT 1 FROM sys.tables WHERE object_id=@Object AND (temporal_type<>0 OR is_memory_optimized=1 OR is_replicated=1 OR is_tracked_by_cdc=1))
 THROW 51961,'Unexpected {name} table behaviour.',1;
"""
    # A separate dynamic batch gives every expected fixture its own temp-table
    # scope. All actual schema changes remain in the enclosing transaction.
    compare = (
        f"DECLARE @Object int=OBJECT_ID(N'dbo.{name}'),@Expected int;\n"
        + expected
        + "\nSET @Expected=OBJECT_ID(N'tempdb..#Expected');\n"
        + checks
        + fk
    )
    return f"IF OBJECT_ID(N'dbo.{name}') IS NULL BEGIN\n{source}\nEND;\nEXEC sys.sp_executesql {quoted(compare)};\n"


def main():
    header = f"""/*
MigrationId: {MIGRATION}
Purpose: Transactional remaining-report receipts and durable processing pipeline stages
Author: cwatts
CreatedUtc: 2026-10-22
RequiresBackup: Yes
RiskLevel: High
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Included
EstimatedRowsAffected: 0 existing application rows
PreValidationQuery: Exact reviewed source preimages, idle authority and writer exclusion
PostValidationQuery: Exact table contracts and paired protected source validation
*/
-- No backfill, import replay, resource settlement or authority activation.
-- Stop/drain the protected pair; apply with the reviewed paired bot contract.
SET NOCOUNT ON; SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51961,'Own migration transaction required.',1;
BEGIN TRANSACTION;
BEGIN TRY
DECLARE @Lock int,@Object int,@Body nvarchar(max);
EXEC @Lock=sys.sp_getapplock @Resource=N'K98:S11:schema',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'Schema busy.',1;
IF OBJECT_ID(N'dbo.StatsImportExecution',N'U') IS NULL OR OBJECT_ID(N'dbo.ExportExecutionSession',N'U') IS NULL
 THROW 51961,'Reviewed import and authority prerequisites required.',1;
IF EXISTS(SELECT 1 FROM dbo.ExportExecutionSession WITH (HOLDLOCK) WHERE State<>'closed')
 THROW 51961,'Authority sessions must be closed.',1;
EXEC @Lock=sys.sp_getapplock @Resource=N'k98-legacy-output-snapshot',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
IF @Lock<0 THROW 51961,'SQL snapshot producer is live.',1;
EXEC dbo.ACQUIRE_KS4_IMPORT_LOCK @LockTimeout=0,@LockResult=@Lock OUTPUT;
IF @Lock<0 THROW 51961,'Scan writer is live.',1;
"""
    text = header + "\n".join(table_install(name) for name in TABLES)
    text += "\n".join(module_install(name) for name in MODULES)
    text += """
DENY EXECUTE ON OBJECT::dbo.usp_S11CompleteStatsReportsCore TO public;
GRANT EXECUTE ON OBJECT::dbo.usp_S11ValidateStatsReportStage TO ExportLegacyEntryReader;
GRANT EXECUTE ON OBJECT::dbo.usp_S11CompleteStatsReports TO ExportLegacyEntryReader;
COMMIT;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
"""
    target = ROOT / "migrations" / (MIGRATION + ".sql")
    target.write_text(text, encoding="utf-8", newline="\n")
    print(target)


if __name__ == "__main__":
    main()
