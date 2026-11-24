"""Read the exact privilege refusal; never replay committed account or SQL setup."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys

PREVIOUS = r"Q:\P02Observer\20261120203443685\receipt.json"
PREVIOUS_SHA = "9af28b25218ce0effd8d31a2dde23794aced9d18eb43daf30cedb3af68bbc3ad"
FIELDS = (
    "target",
    "grants",
    "application_grants",
    "capabilities",
    "module_permissions",
    "token_grants",
    "memberships",
    "ownership",
)
MASTER_FILTER = """p.name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120')
OR p.sid IN (0x0017fc72a83d1941bb993c4613eca7f3,0x4cd6a8a024f24341accad859487b5075)"""
MASTER = {
    "principals": """SELECT p.principal_id,p.name,p.type_desc,p.default_schema_name,
LOWER(CONVERT(varchar(170),p.sid,2)) AS sid FROM master.sys.database_principals p
WHERE """
    + MASTER_FILTER
    + " ORDER BY p.name",
    "grants": """SELECT p.name AS principal,q.class_desc,q.permission_name,q.state_desc,q.minor_id,
CASE q.class WHEN 0 THEN N'master'
WHEN 1 THEN OBJECT_NAME(q.major_id,DB_ID(N'master'))
WHEN 3 THEN (SELECT name FROM master.sys.schemas WHERE schema_id=q.major_id)
ELSE N'unsupported' END AS target_name
FROM master.sys.database_permissions q JOIN master.sys.database_principals p
ON p.principal_id=q.grantee_principal_id WHERE """
    + MASTER_FILTER
    + " ORDER BY p.name,q.class_desc,target_name,q.permission_name,q.minor_id",
    "memberships": """SELECT p.name AS principal,r.name AS role_name
FROM master.sys.database_role_members m JOIN master.sys.database_principals p
ON p.principal_id=m.member_principal_id JOIN master.sys.database_principals r
ON r.principal_id=m.role_principal_id WHERE """
    + MASTER_FILTER
    + " ORDER BY p.name,r.name",
    "ownership": """SELECT p.name,
(SELECT COUNT(*) FROM master.sys.schemas WHERE principal_id=p.principal_id) AS owned_schemas,
(SELECT COUNT(*) FROM master.sys.objects WHERE principal_id=p.principal_id) AS owned_objects,
(SELECT COUNT(*) FROM master.sys.database_principals WHERE owning_principal_id=p.principal_id) AS owned_principals
FROM master.sys.database_principals p WHERE """
    + MASTER_FILTER
    + " ORDER BY p.name",
}


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_prior(prior):
    if (
        prior.get("outcome") != "failed"
        or prior.get("setup_committed") is not True
        or prior.get("commit_binding_verified") is not True
        or prior.get("login_disabled") is not True
        or prior.get("cleanup_failures") != []
        or prior.get("admin_connections_closed") != 1
        or prior.get("first_failure", {}).get("detail")
        != "Direct privileges differ from the exact reviewed grant plan."
        or prior.get("before") != prior.get("after")
        or prior.get("application_reader", {}).get("connections")
        != [dict(closed=True, close_failed=False) for _ in range(3)]
    ):
        raise ValueError("Exact committed mapping and closed failed comparator required")


def difference(actual, expected):
    def encode(row):
        return json.dumps(row, sort_keys=True, separators=(",", ":"))

    left, right = sorted(map(encode, actual)), sorted(map(encode, expected))
    # Preserve duplicate counts, not only set equality.
    from collections import Counter

    a, e = Counter(left), Counter(right)
    return dict(
        missing=[json.loads(row) for row in (e - a).elements()],
        extra=[json.loads(row) for row in (a - e).elements()],
    )


def collect_privileges(connect, candidate, expected, receipt):
    from kvk.dal.new_source_import_dal import rows
    from scripts.verify_k98_running_release import ObservationConnections
    from services.application_observation_schedule import read_owned_observation
    from services.export_execution_dal import legacy_permission_queries

    queries = legacy_permission_queries(candidate["legacy_sql_contract"]["source"])
    owner = ObservationConnections(connect)

    def collect(cursor):
        observed = {}
        for name in FIELDS:
            sql, parameters = queries[name]
            cursor.execute(sql, *parameters)
            observed[name] = rows(cursor)
            if name == "target" and observed[name] != expected[name]:
                raise ValueError("Actual application target differs")
        return observed

    try:
        with owner:
            owner.observation_phase("legacy")
            actual = read_owned_observation(owner, collect, request=owner.observation_request())
        receipt["differences"] = {name: difference(actual[name], expected[name]) for name in FIELDS}
        return actual
    finally:
        receipt["application_reader"] = owner.evidence()


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "committed-application-privilege-read"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated privilege reader required")
    for name, digest in manifest["files"].items():
        member = (packet / name).resolve()
        if not member.is_relative_to(packet) or sha(member.read_bytes()) != digest:
            raise ValueError("Sealed privilege reader changed")
    raw = (packet / "evidence/committed-mapping.json").read_bytes()
    if sha(raw) != PREVIOUS_SHA or Path(PREVIOUS).read_bytes() != raw:
        raise ValueError("Retained committed mapping receipt changed")
    prior = json.loads(raw)
    require_prior(prior)
    sys.path[:0] = [
        str(packet / "bot"),
        str(packet / "qualification/p02_observer"),
        r"C:\discord_file_downloader\venv\Lib\site-packages",
    ]
    os.environ["PYTHON_DOTENV_DISABLED"] = "1"
    import application_identity as identity
    import pyodbc
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    pyodbc.pooling = False
    receipt = dict(
        schema="p02-application-privilege-read/1",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        setup_replayed=False,
        migration_replayed=False,
        restore_replayed=False,
        production_operations=0,
        business_operations=0,
        permission_changes=0,
        contracts_verified=False,
        admin_connections_closed=0,
        login_disabled=False,
    )
    admin = None
    enable_attempted = False

    def save():
        (packet / "receipt.json").write_text(json.dumps(receipt, indent=2, default=str) + "\n")

    def read(statement):
        cursor = admin.cursor()
        first = None
        try:
            cursor.execute(statement)
            if cursor.description:
                names = [v[0] for v in cursor.description]
                values = cursor.fetchmany(501)
                if len(values) > 500 or cursor.nextset():
                    raise ValueError("Bounded single result required")
                return [dict(zip(names, row, strict=True)) for row in values]
            while cursor.nextset():
                if cursor.description:
                    raise ValueError("Unexpected control result")
            return []
        except BaseException as error:
            first = error
            raise
        finally:
            try:
                cursor.close()
            except BaseException:
                receipt["cleanup_failures"].append("admin cursor close unconfirmed")
                if first is None:
                    raise

    def state():
        value = dict(
            target=read(identity.TARGET),
            history=read(identity.HISTORY),
            logins=read(control.LOGIN_STATE),
            server_permissions=read(control.SERVER_PERMISSIONS),
            server_roles=read(control.SERVER_ROLES),
        )
        identity.validate_target(value["target"])
        if value["logins"] != prior["logins_after"] or value["server_roles"]:
            raise ValueError("Completed disabled login mapping changed")
        if identity.normalized_history(value["history"]) != identity.normalized_history(
            prior["after"]["history"]
        ):
            raise ValueError("Completed migration history changed")
        for name, sql in identity.QUERIES.items():
            if name not in ("logins", "server_permissions", "server_roles"):
                value[name] = read(sql)
                if json.loads(json.dumps(value[name], default=str)) != prior["after"][name]:
                    raise ValueError("Retained database state changed: " + name)
        return value

    base = (
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
        "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
    )
    try:
        admin = pyodbc.connect(base + "Trusted_Connection=yes", autocommit=True, timeout=3)
        admin.timeout = 3
        receipt["before"] = state()
        if read(control.SESSIONS):
            raise ValueError("Existing application session retained")
        receipt["master_before"] = {name: read(sql) for name, sql in MASTER.items()}
        encrypted = Path(control.CREDENTIAL_PATH).read_bytes()
        if sha(encrypted) != prior["credential"]["sha256"]:
            raise ValueError("Original guest-only credential changed")
        password = control.unprotect(encrypted)
        candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
        expected = json.loads((packet / "expected-legacy.json").read_bytes())
        enable_attempted = True
        read(control.ENABLE)
        actual = collect_privileges(
            lambda: pyodbc.connect(
                base + f"UID={control.PRINCIPAL};PWD={{{password}}};APP=P02PrivilegeRead;",
                autocommit=True,
                timeout=3,
            ),
            candidate,
            expected,
            receipt,
        )
        password = None
        with (packet / "combined-observation.json").open("x", encoding="utf-8") as stream:
            json.dump(actual, stream, indent=2, default=str)
        receipt["outcome"] = "passed"
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = sql_error_facts(error)
        if isinstance(error, ValueError):
            receipt["first_failure"]["detail"] = str(error)[:400]
    finally:
        if admin is not None:
            if enable_attempted:
                try:
                    read(control.DISABLE)
                    receipt["login_disabled"] = True
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="disable mapped login", **sql_error_facts(error))
                    )
            if not receipt["cleanup_failures"] and "before" in receipt:
                try:
                    receipt["after"] = state()
                    receipt["master_after"] = {name: read(sql) for name, sql in MASTER.items()}
                    if (
                        receipt["after"] != receipt["before"]
                        or receipt["master_after"] != receipt["master_before"]
                        or read(control.SESSIONS)
                    ):
                        raise ValueError("Read-only state or application closure differs")
                except BaseException as error:
                    receipt["cleanup_failures"].append(
                        dict(operation="read-only state reconciliation", **sql_error_facts(error))
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
        receipt["finished"] = datetime.now(UTC).isoformat()
        save()
    return 0 if receipt["outcome"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
