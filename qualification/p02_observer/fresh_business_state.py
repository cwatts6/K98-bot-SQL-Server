"""Exact DB16 preservation and DB18 qualification identity; no policy overrides."""

from copy import deepcopy
from datetime import datetime, timedelta
import json

FRESH = "K98_P02Business_20261121180254259"
RETAINED = "K98_P02Claim_Retained_20261121181435617"
FILES = {
    16: r"Q:\P02Release\K98_P02Release_20261120153927686\baseline.mdf",
    18: r"R:\K98_P02Business_20261121180254259\baseline.mdf",
}
DATABASES = """SELECT d.database_id,d.name,d.create_date,d.state_desc,d.user_access_desc,
d.is_read_only,d.source_database_id,LOWER(CONVERT(varchar(170),d.owner_sid,2)) AS owner_sid,
CONVERT(varchar(36),r.database_guid) AS database_guid,
CONVERT(varchar(36),r.family_guid) AS family_guid
FROM sys.databases d LEFT JOIN sys.database_recovery_status r ON r.database_id=d.database_id
ORDER BY d.database_id"""
FILE_IDENTITIES = """SELECT database_id,file_id,name,physical_name,type_desc,
CONVERT(varchar(36),file_guid) AS file_guid FROM sys.master_files
WHERE database_id IN (16,18) ORDER BY database_id,file_id"""
SESSIONS = """SELECT s.session_id,s.login_name,s.database_id,r.database_id AS request_database,
s.open_transaction_count FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON r.session_id=s.session_id
WHERE s.is_user_process=1 AND s.session_id<>@@SPID
AND (s.database_id IN (16,18) OR r.database_id IN (16,18)
OR s.login_name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120'))"""
LOCKS = """SELECT request_session_id,resource_database_id,resource_type,request_status
FROM sys.dm_tran_locks WHERE resource_database_id IN (16,18)
AND request_session_id<>@@SPID AND request_session_id>0"""
IDENTITY = """SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,
CONVERT(nvarchar(128),SERVERPROPERTY('ProductVersion')) AS product_version,
ORIGINAL_LOGIN() AS login_name,IS_SRVROLEMEMBER('sysadmin') AS administrator,
DB_NAME() AS database_name,DB_ID() AS database_id"""
CLOCK = "SELECT SYSDATETIME() AS local_time"


def normalized(value):
    return json.loads(json.dumps(value, default=str))


def require_restore(value):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failure") is not None
        or value.get("execution_settled") is not True
        or value.get("connections_closed") != 1
        or value.get("preservation_connections_closed") != 2
        or value.get("restore_committed") is not True
        or value.get("fresh_owner_committed") is not True
        or len(value.get("history", [])) != 105
        or value.get("observer_objects") != []
        or value.get("database", [{}])[0].get("database_id") != 18
        or value["database"][0].get("name") != FRESH
    ):
        raise ValueError("Exact completed restricted DB18 restore required")


def require_native_reader(value, expected):
    if (
        value.get("outcome") != "passed"
        or value.get("first_failure") is not None
        or value.get("cleanup_failures") != []
        or value.get("connections_closed") != 1
        or value.get("physical_custody_retained") is not False
        or value.get("before_differences") != []
        or value.get("after_differences") != []
        or value.get("before") != expected
        or value.get("after") != expected
    ):
        raise ValueError("Complete settled original preservation reader required")


def require_identity(rows, database, database_id):
    expected = dict(
        server_name="MINI_AMD",
        product_version="16.0.1220.3",
        login_name=r"MINI_AMD\K98LabAdmin",
        administrator=1,
        database_name=database,
        database_id=database_id,
    )
    if rows != [expected]:
        raise ValueError("Exact isolated SQL instance and physical database required")


def require_files(rows):
    if len(rows) != 4:
        raise ValueError("Two exact retained databases and two files each required")
    for number, path in FILES.items():
        data = [r for r in rows if r["database_id"] == number]
        if (
            [r["file_id"] for r in data] != [1, 2]
            or data[0]["physical_name"] != path
            or data[1]["physical_name"] != path.replace("baseline.mdf", "baseline_log.ldf")
            or any(not r["file_guid"] for r in data)
        ):
            raise ValueError("Physical file identity differs")


def require_handover(before, after, files_before, files_after, changes):
    """Allow only acknowledged name/date changes; keep every raw observation."""
    require_files(files_before)
    if files_after != files_before or len(before) != len(after):
        raise ValueError("Physical files or database inventory changed")
    expected = deepcopy(before)
    for row in expected:
        item = changes.get(row["database_id"])
        if item is None:
            continue
        current = next((r for r in after if r["database_id"] == row["database_id"]), None)
        if current is None or item["acknowledged"] is not True:
            raise ValueError("Name transition lacks an acknowledged owner")
        stamp = datetime.fromisoformat(current["create_date"])
        old = datetime.fromisoformat(row["create_date"])
        if stamp != old and not (
            datetime.fromisoformat(item["before"]) - timedelta(milliseconds=4)
            <= stamp
            <= datetime.fromisoformat(item["after"]) + timedelta(milliseconds=4)
        ):
            raise ValueError("Rename timestamp outside acknowledged operation")
        row.update(name=item["name"], create_date=current["create_date"])
        if item.get("multi_user"):
            row["user_access_desc"] = "MULTI_USER"
    if after != expected:
        raise ValueError("Database state changed beyond acknowledged name transitions")
    return expected


def expected_original(original, name, create_date):
    if name not in ("ROK_TRACKER", RETAINED):
        raise ValueError("Original DB16 name not owned by this qualification")
    wanted = deepcopy(original)
    target = wanted["database"]["target"][0]
    if target["database_id"] != 16:
        raise ValueError("Original physical database required")
    target.update(database_name=name, create_date=create_date)
    for row in wanted["database"]["database_permissions"]:
        if row["class_desc"] == "DATABASE" and row["target_name"] == "ROK_TRACKER":
            row["target_name"] = name
    for row in wanted["database"]["retained_databases"]:
        if row["database_id"] == 16:
            row["name"] = name
    return wanted


def original_state(owner, expected, name):
    import application_identity as identity
    import application_privileges as audit
    from producer_fixture import FRESH_ACCOUNT, ORIGINAL_PREPARATIONS, RESOURCE_SQL
    import report_failure_read as old
    import restart_read as shared
    import three_contracts as control

    require_identity(owner.read(IDENTITY), name, 16)
    read = owner.read
    value = dict(
        target=read(identity.TARGET),
        history=read(identity.HISTORY),
        logins=read(control.LOGIN_STATE),
        server_permissions=read(control.SERVER_PERMISSIONS),
        server_roles=read(control.SERVER_ROLES),
    )
    for key, sql in identity.QUERIES.items():
        if key not in ("logins", "server_permissions", "server_roles"):
            value[key] = read(sql)
    # Only an exact constant qualification name can select the retained DB16.
    hashes = {
        table: read(old.digest_sql("ROK_TRACKER", table).replace("[ROK_TRACKER]", "[" + name + "]"))
        for table in old.OBJECTS
    }
    actual = normalized(
        dict(
            database=value,
            master={k: read(s) for k, s in audit.MASTER.items()},
            application_sessions=read(SESSIONS),
            ownership=dict(
                preparations=read(FRESH_ACCOUNT, old.ACCOUNT),
                resources=read(RESOURCE_SQL, "account:" + old.ACCOUNT),
                original_preparations=read(ORIGINAL_PREPARATIONS, old.ACCOUNT, old.ACCOUNT),
            ),
            snapshot=read(old.SNAPSHOT_SQL),
            business_hashes=hashes,
        )
    )
    owner.record.setdefault("original_observations", []).append(actual)
    if actual != expected:
        raise ValueError("Original setup, claim, snapshot or business state changed")
    return dict(
        state=actual,
        owner=normalized(read(shared.OWNER_SQL)),
        modules=normalized(read(old.MODULE_SQL)),
    )
