"""Read the committed lab incarnation and application identity prerequisites only."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from uuid import UUID

TARGET = """SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,
CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,
DB_NAME() AS database_name,DB_ID() AS database_id,ORIGINAL_LOGIN() AS login_name,
create_date,state_desc,is_read_only,snapshot_isolation_state,is_read_committed_snapshot_on
FROM sys.databases WHERE database_id=DB_ID()"""
HISTORY = """SELECT MigrationId,ChecksumSha256,GitCommit,DeploymentId,Status
FROM dbo.SchemaMigrationHistory ORDER BY MigrationId"""
QUERIES = {
    "logins": """SELECT name,type_desc,is_disabled,LOWER(CONVERT(varchar(170),sid,2)) AS sid
FROM sys.server_principals
WHERE name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual')
OR sid=0x4cd6a8a024f24341accad859487b5075 ORDER BY name""",
    "server_roles": """SELECT p.name AS principal,r.name AS role_name
FROM sys.server_role_members m JOIN sys.server_principals p ON p.principal_id=m.member_principal_id
JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual') ORDER BY p.name,r.name""",
    "server_permissions": """SELECT p.name AS principal,q.class_desc,q.permission_name,q.state_desc
FROM sys.server_permissions q JOIN sys.server_principals p ON p.principal_id=q.grantee_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual')
ORDER BY p.name,q.class_desc,q.permission_name""",
    "database_users": """SELECT name,type_desc,authentication_type_desc,default_schema_name,
LOWER(CONVERT(varchar(170),sid,2)) AS sid FROM sys.database_principals
WHERE name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual')
OR sid=0x4cd6a8a024f24341accad859487b5075 ORDER BY name""",
    "database_roles": """SELECT p.name AS principal,r.name AS role_name
FROM sys.database_role_members m JOIN sys.database_principals p ON p.principal_id=m.member_principal_id
JOIN sys.database_principals r ON r.principal_id=m.role_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual') ORDER BY p.name,r.name""",
    "database_permissions": """SELECT p.name AS principal,q.class_desc,q.permission_name,q.state_desc,
CASE WHEN q.class=1 THEN OBJECT_SCHEMA_NAME(q.major_id)+N'.'+OBJECT_NAME(q.major_id)
WHEN q.class=3 THEN SCHEMA_NAME(q.major_id) ELSE DB_NAME() END AS target_name,q.minor_id
FROM sys.database_permissions q JOIN sys.database_principals p ON p.principal_id=q.grantee_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual')
ORDER BY p.name,q.class_desc,target_name,q.permission_name,q.minor_id""",
    "msdb_users": """SELECT name,type_desc,authentication_type_desc,
LOWER(CONVERT(varchar(170),sid,2)) AS sid FROM msdb.sys.database_principals
WHERE name IN (N'S11_ExportApplication',N'S11_ExportApplication_P02ObserverQual') ORDER BY name""",
    "observer_sequence": """SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation
FROM sys.sequences WHERE name=N'P02ObservationGeneration'""",
    "retained_sequence": """SELECT object_id,create_date,modify_date,CONVERT(bigint,current_value) AS generation
FROM [K98_P02Observer_Retained_20261120153927686].sys.sequences WHERE name=N'P02ObservationGeneration'""",
    "retained_databases": """SELECT name,database_id,state_desc,source_database_id
FROM sys.databases WHERE database_id IN (11,12,14,15,16) ORDER BY database_id""",
    "msdb_identity": """SELECT d.name,d.database_id,d.state_desc,d.user_access_desc,d.is_broker_enabled,
CONVERT(varchar(36),r.database_guid) AS database_guid,CONVERT(varchar(36),r.family_guid) AS family_guid
FROM sys.databases d JOIN sys.database_recovery_status r ON r.database_id=d.database_id WHERE d.name=N'msdb'""",
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def normalized_history(rows):
    return [{**row, "DeploymentId": str(UUID(str(row["DeploymentId"])))} for row in rows]


def validate_target(rows):
    if len(rows) != 1:
        raise ValueError("One exact lab target required")
    row = rows[0]
    if (
        row["server_name"] != "MINI_AMD"
        or row["product_version"] != "16.0.1220.3"
        or row["database_name"] != "ROK_TRACKER"
        or row["database_id"] != 16
        or row["login_name"].casefold() != r"MINI_AMD\K98LabAdmin".casefold()
        or row["create_date"] != datetime(2026, 11, 20, 16, 19, 45, 563000)
        or row["state_desc"] != "ONLINE"
        or row["is_read_only"]
        or row["snapshot_isolation_state"] != 1
        or row["is_read_committed_snapshot_on"]
    ):
        raise ValueError("Exact retained DB16 and local administrative reader required")


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["stage"] != "observer-release-preflight-read"
        or manifest["purpose"] != "committed-observer-application-identity"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated read-only packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed identity reader changed")
    prior_raw = (packet / "evidence/committed-observer.json").read_bytes()
    if sha(prior_raw) != "c67fb4d3481575b7556ce7db4af1ee53831c939ec09fdfbe4403915c90023a95":
        raise ValueError("Exact completed observer receipt required")
    prior = json.loads(prior_raw)
    on_disk = json.loads(
        Path(r"Q:\P02Release\observer-release-20261120194240117\guest-receipt.json").read_bytes()
    )
    if on_disk != prior or prior["outcome"] != "passed" or not prior["execution_settled"]:
        raise ValueError("Completed observer receipt changed")
    sys.path[:0] = [str(packet / "bot"), r"C:\discord_file_downloader\venv\Lib\site-packages"]
    os.environ["PYTHON_DOTENV_DISABLED"] = "1"
    import pyodbc

    from services.observer_release_dal import committed_observer_receipt

    pyodbc.pooling = False
    receipt = dict(
        schema="p02-committed-observer-identity/1",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        production_operations=0,
        business_operations=0,
        sql_changes=0,
        installation_replayed=False,
        connections_closed=0,
        dispatches=0,
        timings=[],
        first_failure=None,
        cleanup_failure=None,
        application_authentication_proven=False,
    )
    connection = None
    started = time.monotonic()

    def save():
        (packet / "receipt.json").write_text(
            json.dumps(receipt, indent=2, default=str) + "\n", encoding="utf-8"
        )

    def read(sql):
        if time.monotonic() - started > 45 or receipt["dispatches"] >= 32:
            raise TimeoutError("Bounded read-only identity budget exhausted")
        receipt["dispatches"] += 1
        cursor = connection.cursor()
        tick = time.monotonic()
        first = None
        try:
            cursor.execute(sql)
            fields = [c[0] for c in cursor.description]
            values = cursor.fetchmany(257)
            if len(values) > 256 or cursor.nextset():
                raise ValueError("Bounded single result required")
            return [dict(zip(fields, row, strict=True)) for row in values]
        except BaseException as exc:
            first = exc
            raise
        finally:
            try:
                cursor.close()
            except BaseException:
                receipt["cleanup_failure"] = "cursor close not acknowledged"
                if first is None:
                    raise
            receipt["timings"].append(
                dict(dispatch=receipt["dispatches"], seconds=time.monotonic() - tick)
            )
            save()

    try:
        connection = pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Trusted_Connection=yes;Encrypt=yes;"
            "TrustServerCertificate=yes;APP=P02ObserverIdentityRead;",
            autocommit=True,
            timeout=3,
        )
        connection.timeout = 3
        receipt["target"] = read(TARGET)
        validate_target(receipt["target"])
        receipt["history_before"] = read(HISTORY)
        if normalized_history(receipt["history_before"]) != normalized_history(
            prior["after"]["history"]
        ):
            raise ValueError("Committed migration history differs")
        for name, sql in QUERIES.items():
            receipt[name] = read(sql)
        actual = receipt["observer_sequence"]
        wanted = prior["observation_installation"]
        if (
            len(actual) != 1
            or actual[0]["object_id"] != wanted["sequence_object_id"]
            or actual[0]["create_date"].isoformat(timespec="microseconds")
            != wanted["sequence_created"]
            or actual[0]["modify_date"].isoformat(timespec="microseconds")
            != wanted["sequence_modified"]
            or actual[0]["generation"] != 1
        ):
            raise ValueError("Committed observer incarnation changed")
        receipt["dispatches"] += 1
        cursor = connection.cursor()
        tick = time.monotonic()
        first = None
        try:
            # The actual DAL is exercised with native ODBC types. This admin
            # observation is explicitly not application authentication evidence.
            receipt["native_dal_receipt"] = committed_observer_receipt(cursor)
        except BaseException as exc:
            first = exc
            raise
        finally:
            try:
                cursor.close()
            except BaseException:
                receipt["cleanup_failure"] = "native DAL cursor close not acknowledged"
                if first is None:
                    raise
            receipt["timings"].append(
                dict(dispatch=receipt["dispatches"], seconds=time.monotonic() - tick)
            )
            save()
        if receipt["native_dal_receipt"]["binding"] != prior["observer_receipt"]["ErrorMessage"]:
            raise ValueError("Native committed binding changed")
        receipt["history_after"] = read(HISTORY)
        if receipt["history_after"] != receipt["history_before"]:
            raise ValueError("Read-only history changed")
        receipt["outcome"] = "passed"
    except BaseException as exc:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = dict(type=type(exc).__name__, detail=str(exc))
    finally:
        if connection is not None:
            try:
                connection.close()
                receipt["connections_closed"] += 1
            except BaseException:
                receipt["cleanup_failure"] = "connection close not acknowledged"
                receipt["outcome"] = "failed"
        receipt["finished"] = datetime.now(UTC).isoformat()
        save()
    return 0 if receipt["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
