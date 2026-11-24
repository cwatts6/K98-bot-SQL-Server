"""One isolated application-authenticated comparison after genuine observer commit."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PRINCIPAL = "S11_ExportApplication"
RETAINED = "S11_ExportApplication_Retained_P02_20261120"
OLD_SID = "0017fc72a83d1941bb993c4613eca7f3"
NEW_SID = "4cd6a8a024f24341accad859487b5075"
PRIOR_SHA = "22459db25f9589162758bb0a9698ae94da9fd0f12303fdaab044c2bd604acc8d"
PRIOR_PATH = r"Q:\P02Observer\20261120200131286\receipt.json"
FAILED_SHA = "4c2eaa99e034fb97bbb3be2bdc448fa73b3d6008f8262116f1edf20eab6fff62"
FAILED_PATH = r"Q:\P02Observer\20261120202003230\receipt.json"
CREDENTIAL_PATH = r"Q:\P02Observer\20261120202003230\application-credential.dpapi"

LOGIN_STATE = """SELECT principal_id,name,type_desc,is_disabled,
LOWER(CONVERT(varchar(170),sid,2)) AS sid,default_database_name,default_language_name,
is_policy_checked,is_expiration_checked FROM sys.sql_logins
WHERE name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120',
N'S11_ExportApplication_P02ObserverQual')
OR sid IN (0x0017fc72a83d1941bb993c4613eca7f3,0x4cd6a8a024f24341accad859487b5075)
ORDER BY name"""
SERVER_PERMISSIONS = """SELECT p.name AS principal,q.class_desc,q.permission_name,q.state_desc
FROM sys.server_permissions q JOIN sys.server_principals p ON p.principal_id=q.grantee_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120',
N'S11_ExportApplication_P02ObserverQual')
ORDER BY p.name,q.class_desc,q.permission_name"""
SERVER_ROLES = """SELECT p.name AS principal,r.name AS role_name
FROM sys.server_role_members m JOIN sys.server_principals p ON p.principal_id=m.member_principal_id
JOIN sys.server_principals r ON r.principal_id=m.role_principal_id
WHERE p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120',
N'S11_ExportApplication_P02ObserverQual') ORDER BY p.name,r.name"""
SESSIONS = """SELECT s.session_id,s.login_name,s.status,s.database_id,r.database_id AS request_database
FROM sys.dm_exec_sessions s LEFT JOIN sys.dm_exec_requests r ON r.session_id=s.session_id
WHERE s.is_user_process=1 AND s.session_id<>@@SPID
AND (s.database_id=16 OR r.database_id=16 OR s.login_name IN
(N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120'))"""
SETUP = """SET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;
IF DB_NAME()<>N'ROK_TRACKER' OR DB_ID()<>16 OR @@TRANCOUNT<>0
 OR SERVERPROPERTY('IsIntegratedSecurityOnly')<>0 OR IS_SRVROLEMEMBER('sysadmin')<>1
 THROW 51973,'Exact isolated mapping owner required.',1;
IF NOT EXISTS(SELECT 1 FROM sys.sql_logins WHERE name=N'S11_ExportApplication'
 AND sid=0x0017fc72a83d1941bb993c4613eca7f3 AND is_disabled=1)
 OR EXISTS(SELECT 1 FROM sys.server_principals WHERE
 name=N'S11_ExportApplication_Retained_P02_20261120' OR sid=0x4cd6a8a024f24341accad859487b5075)
 THROW 51973,'Original disabled lab login or new mapping differs.',1;
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N'S11_ExportApplication'
 AND sid=0x4cd6a8a024f24341accad859487b5075 AND type='S')
 THROW 51973,'Original restored database user differs.',1;
DECLARE @Password nvarchar(128)=?;
IF LEN(@Password)<32 THROW 51973,'Private generated credential required.',1;
BEGIN TRY
 BEGIN TRANSACTION;
 ALTER LOGIN [S11_ExportApplication] WITH NAME=[S11_ExportApplication_Retained_P02_20261120];
 DECLARE @Sql nvarchar(max)=N'CREATE LOGIN [S11_ExportApplication] WITH PASSWORD='
 +QUOTENAME(@Password,CHAR(39))
 +N',SID=0x4cd6a8a024f24341accad859487b5075,CHECK_POLICY=ON,CHECK_EXPIRATION=OFF,DEFAULT_DATABASE=[ROK_TRACKER];';
 EXEC sys.sp_executesql @Sql;
 ALTER LOGIN [S11_ExportApplication] DISABLE;
 EXEC master.sys.sp_executesql N'GRANT ADMINISTER BULK OPERATIONS TO [S11_ExportApplication];
 GRANT VIEW SERVER PERFORMANCE STATE TO [S11_ExportApplication];';
 SET @Password=NULL; SET @Sql=NULL;
 COMMIT TRANSACTION;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;"""
ENABLE = """IF NOT EXISTS(SELECT 1 FROM sys.sql_logins WHERE name=N'S11_ExportApplication'
AND sid=0x4cd6a8a024f24341accad859487b5075 AND is_disabled=1)
THROW 51973,'Exact disabled new lab login required.',1;
ALTER LOGIN [S11_ExportApplication] ENABLE;"""
DISABLE = """IF NOT EXISTS(SELECT 1 FROM sys.sql_logins WHERE name=N'S11_ExportApplication'
AND sid=0x4cd6a8a024f24341accad859487b5075)
THROW 51973,'Exact new lab login required for cleanup.',1;
ALTER LOGIN [S11_ExportApplication] DISABLE;"""


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_failed_attempt(failed):
    expected = dict(
        stage="preserve old disabled login and create exact restored-user mapping",
        error_type="ProgrammingError",
        sqlstate="42000",
        native_code=4621,
    )
    if (
        failed.get("outcome") != "failed"
        or failed.get("first_failure") != expected
        or failed.get("setup_attempted") is not True
        or failed.get("setup_committed") is not False
        or failed.get("admin_connections_closed") != 1
        or failed.get("admin_dispatches") != 15
        or failed.get("cleanup_failures") != []
        or failed.get("application_authentication_proven") is not False
        or failed.get("commit_binding_verified") is not False
        or "application_reader" in failed
        or failed.get("credential", {}).get("path") != CREDENTIAL_PATH
    ):
        raise ValueError("Exact stopped setup and acknowledged cleanup required")


def unprotect(blob):
    import base64
    import subprocess

    command = (
        "$ErrorActionPreference='Stop';"
        "[void][Reflection.Assembly]::Load('System.Security, Version=4.0.0.0, "
        "Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a');"
        "[Console]::Out.Write([Text.Encoding]::UTF8.GetString("
        "[Security.Cryptography.ProtectedData]::Unprotect("
        "[Convert]::FromBase64String([Console]::In.ReadToEnd()),$null,"
        "[Security.Cryptography.DataProtectionScope]::CurrentUser)))"
    )
    result = subprocess.run(
        [
            r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            command,
        ],
        input=base64.b64encode(blob).decode(),
        capture_output=True,
        text=True,
        timeout=10,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    if result.returncode or not re.fullmatch(r"Aa1![A-Za-z0-9_-]{64}", result.stdout):
        raise ValueError("Original private guest credential unavailable")
    return result.stdout


def run_contracts(connect, candidate, config, receipt, *, owner=None):
    from scripts.verify_k98_running_release import ObservationConnections
    from scripts.verify_k98_update_pair import verify_bot_sql_contracts
    from services.application_observation_schedule import read_owned_observation
    from services.observer_release_dal import committed_observer_receipt
    from services.observer_release_issuance import bind_observer_candidate

    owner = owner if owner is not None else ObservationConnections(connect)
    start = time.monotonic()
    try:
        with owner:
            native = read_owned_observation(
                owner, committed_observer_receipt, request=owner.observation_request()
            )
            receipt["native_application_receipt"] = native
            bound = bind_observer_candidate(config, candidate, native)
            receipt["commit_binding_verified"] = True
            collected = verify_bot_sql_contracts(bound, connection_factory=owner)
        return collected
    finally:
        receipt["application_reader"] = owner.evidence()
        receipt["application_seconds"] = time.monotonic() - start


def require_login_state(before, after):
    old = next(row for row in before if row["name"] == PRINCIPAL)
    retained = next((row for row in after if row["name"] == RETAINED), None)
    if retained != dict(old, name=RETAINED):
        raise ValueError("Retained disabled login metadata changed")
    others_before = [row for row in before if row["name"] != PRINCIPAL]
    others_after = [row for row in after if row["name"] not in (PRINCIPAL, RETAINED)]
    if others_before != others_after:
        raise ValueError("Earlier qualification login changed")
    new = [row for row in after if row["name"] == PRINCIPAL]
    if (
        len(new) != 1
        or new[0]["sid"] != NEW_SID
        or not new[0]["is_disabled"]
        or new[0]["type_desc"] != "SQL_LOGIN"
        or new[0]["default_database_name"] != "ROK_TRACKER"
        or not new[0]["is_policy_checked"]
        or new[0]["is_expiration_checked"]
    ):
        raise ValueError("New disabled restored-user mapping differs")


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["stage"] != "restored-application-observer"
        or manifest["purpose"] != "committed-three-contract-reader"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated three-contract packet required")
    for name, digest in manifest["files"].items():
        path = (packet / name).resolve()
        if not path.is_relative_to(packet) or sha(path.read_bytes()) != digest:
            raise ValueError("Sealed three-contract member changed")
    prior_raw = (packet / "evidence/application-identity.json").read_bytes()
    if sha(prior_raw) != PRIOR_SHA or Path(PRIOR_PATH).read_bytes() != prior_raw:
        raise ValueError("Completed read-only identity receipt changed")
    prior = json.loads(prior_raw)
    failed_raw = (packet / "evidence/stopped-setup.json").read_bytes()
    if sha(failed_raw) != FAILED_SHA or Path(FAILED_PATH).read_bytes() != failed_raw:
        raise ValueError("Exact retained setup failure changed")
    failed = json.loads(failed_raw)
    require_failed_attempt(failed)
    sys.path[:0] = [
        str(packet / "bot"),
        r"C:\discord_file_downloader\venv\Lib\site-packages",
        str(packet / "qualification/p02_observer"),
    ]
    os.environ["PYTHON_DOTENV_DISABLED"] = "1"
    import application_identity as identity
    import pyodbc
    from scripts.verify_k98_running_release import sql_error_facts

    pyodbc.pooling = False
    receipt = dict(
        schema="p02-committed-three-contract-proof/1",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        stage="preflight",
        stages=[],
        production_operations=0,
        business_operations=0,
        restore_replayed=False,
        migration_replayed=False,
        protected_seed_written=False,
        application_authentication_proven=False,
        commit_binding_verified=False,
        admin_connections_closed=0,
        admin_dispatches=0,
        first_failure=None,
        cleanup_failures=[],
        setup_attempted=False,
        setup_committed=False,
        login_disabled=False,
    )
    admin = None
    enable_attempted = False

    def save():
        (packet / "receipt.json").write_text(
            json.dumps(receipt, indent=2, default=str) + "\n", encoding="utf-8"
        )

    def stage(name):
        receipt["stage"] = name
        receipt["stages"].append(dict(name=name, utc=datetime.now(UTC).isoformat()))
        save()

    def query(statement, *parameters):
        receipt["admin_dispatches"] += 1
        cursor = admin.cursor()
        first = None
        try:
            cursor.execute(statement, *parameters)
            if cursor.description:
                columns = [item[0] for item in cursor.description]
                values = cursor.fetchmany(501)
                if len(values) > 500 or cursor.nextset():
                    raise ValueError("Bounded single administrative result required")
                return [dict(zip(columns, row, strict=True)) for row in values]
            while cursor.nextset():
                if cursor.description:
                    raise ValueError("Unexpected administrative mutation result")
            return []
        except BaseException as error:
            first = error
            raise
        finally:
            try:
                cursor.close()
            except BaseException:
                receipt["cleanup_failures"].append("administrative cursor close unconfirmed")
                if first is None:
                    raise

    def invariant_state():
        result = {"target": query(identity.TARGET), "history": query(identity.HISTORY)}
        identity.validate_target(result["target"])
        for name, statement in identity.QUERIES.items():
            if name not in ("logins", "server_permissions", "server_roles"):
                result[name] = query(statement)
        if identity.normalized_history(result["history"]) != identity.normalized_history(
            prior["history_after"]
        ):
            raise ValueError("Genuine 106-row migration history changed")
        # The identity receipt serialized SQL datetimes as space-separated strings.
        for name in result:
            if name in prior and json.loads(json.dumps(result[name], default=str)) != prior[name]:
                raise ValueError("Retained fixture state changed: " + name)
        return result

    base = (
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
        "Encrypt=yes;TrustServerCertificate=yes;DATABASE=ROK_TRACKER;"
    )
    try:
        admin = pyodbc.connect(base + "Trusted_Connection=yes", autocommit=True, timeout=3)
        admin.timeout = 3
        receipt["before"] = invariant_state()
        if json.loads(json.dumps(receipt["before"], default=str)) != failed["before"]:
            raise ValueError("Earlier failure's complete pre-state differs")
        if query(SESSIONS):
            raise ValueError("Existing application session retained; no forced cleanup")
        before = query(LOGIN_STATE)
        receipt["logins_before"] = before
        if before != failed["logins_before"]:
            raise ValueError("Original disabled login metadata changed after failed attempt")
        receipt["previous_failure_reconciled"] = FAILED_SHA
        old = [row for row in before if row["name"] == PRINCIPAL]
        if (
            len(before) != 2
            or len(old) != 1
            or old[0]["sid"] != OLD_SID
            or not old[0]["is_disabled"]
            or any(row["sid"] == NEW_SID for row in before)
            or any(row["name"] == RETAINED for row in before)
        ):
            raise ValueError("Exact original disabled login state required")
        if query(SERVER_ROLES) != prior["server_roles"] or prior["server_roles"]:
            raise ValueError("Unexpected server role membership")
        permissions = query(SERVER_PERMISSIONS)
        if permissions != prior["server_permissions"]:
            raise ValueError("Original server rights changed")
        expected_permissions = [
            dict(
                principal=RETAINED if row["principal"] == PRINCIPAL else row["principal"],
                **{key: value for key, value in row.items() if key != "principal"},
            )
            for row in permissions
        ] + [row for row in permissions if row["principal"] == PRINCIPAL]
        expected_permissions.sort(
            key=lambda row: (row["principal"], row["class_desc"], row["permission_name"])
        )
        encrypted = Path(CREDENTIAL_PATH).read_bytes()
        if sha(encrypted) != failed["credential"]["sha256"]:
            raise ValueError("Retained guest-only credential differs")
        password = unprotect(encrypted)
        receipt["credential"] = dict(failed["credential"], reused=True)
        stage("preserve old disabled login and create exact restored-user mapping")
        receipt["setup_attempted"] = True
        save()
        query(SETUP, password)
        receipt["setup_committed"] = True
        save()
        require_login_state(before, query(LOGIN_STATE))
        if query(SERVER_PERMISSIONS) != expected_permissions or query(SERVER_ROLES):
            raise ValueError("Mapped server permission set differs")
        stage("application-authenticated committed receipt and complete three contracts")
        enable_attempted = True
        query(ENABLE)
        candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
        config = manifest["release"]
        collected = run_contracts(
            lambda: pyodbc.connect(
                base + f"UID={PRINCIPAL};PWD={{{password}}};APP=P02ObserverThreeContracts;",
                autocommit=True,
                timeout=3,
            ),
            candidate,
            config,
            receipt,
        )
        password = None
        with (packet / "combined-observation.json").open("x", encoding="utf-8") as stream:
            json.dump(collected, stream, indent=2, default=str)
        receipt["application_authentication_proven"] = True
        receipt["outcome"] = "passed"
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = dict(stage=receipt["stage"], **sql_error_facts(error))
        if isinstance(error, (ValueError, AssertionError)):
            receipt["first_failure"]["detail"] = str(error)[:400]
    finally:
        if admin is not None:
            if enable_attempted:
                try:
                    query(DISABLE)
                    receipt["login_disabled"] = True
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="disable new mapped login", **sql_error_facts(error))
                    )
            if receipt["setup_committed"] and not receipt["cleanup_failures"]:
                try:
                    receipt["logins_after"] = query(LOGIN_STATE)
                    require_login_state(receipt["logins_before"], receipt["logins_after"])
                    receipt["after"] = invariant_state()
                    if query(SERVER_PERMISSIONS) != expected_permissions or query(SERVER_ROLES):
                        raise ValueError("Final mapped server permissions differ")
                    if query(SESSIONS):
                        raise ValueError("Application session closure not confirmed")
                    receipt["login_disabled"] = True
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(
                            operation="final preserved-state reconciliation",
                            **sql_error_facts(error),
                        )
                    )
            try:
                admin.close()
                receipt["admin_connections_closed"] += 1
            except BaseException as error:
                receipt["cleanup_failures"].append(
                    dict(operation="admin close", **sql_error_facts(error))
                )
        if receipt["cleanup_failures"]:
            receipt["outcome"] = "failed"
        if receipt["outcome"] == "passed":
            stage("three contracts verified; mapping disabled; completed migrations preserved")
        receipt["finished"] = datetime.now(UTC).isoformat()
        save()
    return 0 if receipt["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
