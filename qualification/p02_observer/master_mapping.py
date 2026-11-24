"""Map only the missing master user, then continue the genuine three-contract reader."""

from datetime import UTC, datetime
import hashlib
import json
import os
from pathlib import Path
import sys

PREVIOUS = r"Q:\P02Observer\20261120204133587\receipt.json"
PREVIOUS_SHA = "3701f19655763e6ed5365cf3af6fc7a8c1b1ec0eebabcfb718697d40b700b0d9"
MASTER_SETUP = "IF DB_NAME()<>N'ROK_TRACKER' OR DB_ID()<>16 OR @@TRANCOUNT<>0\n OR IS_SRVROLEMEMBER('sysadmin')<>1\n THROW 51973,'Exact isolated master mapping owner required.',1;\nEXEC master.sys.sp_executesql N'\nSET NOCOUNT ON; SET XACT_ABORT ON; SET LOCK_TIMEOUT 1000;\nIF DB_ID()<>1 OR @@TRANCOUNT<>0\n OR NOT EXISTS(SELECT 1 FROM sys.sql_logins WHERE name=N''S11_ExportApplication''\n AND sid=0x4cd6a8a024f24341accad859487b5075 AND is_disabled=1)\n OR NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE name=N''S11_ExportApplication''\n AND principal_id=7 AND sid=0x0017fc72a83d1941bb993c4613eca7f3 AND type=''S'')\n OR EXISTS(SELECT 1 FROM sys.database_principals\n WHERE name=N''S11_ExportApplication_Retained_P02_20261120''\n OR sid=0x4cd6a8a024f24341accad859487b5075)\n THROW 51973,''Original master mapping changed.'',1;\nBEGIN TRY\n BEGIN TRANSACTION;\n ALTER USER [S11_ExportApplication] WITH NAME=[S11_ExportApplication_Retained_P02_20261120];\n CREATE USER [S11_ExportApplication] FOR LOGIN [S11_ExportApplication] WITH DEFAULT_SCHEMA=[dbo];\n GRANT CONNECT TO [S11_ExportApplication];\n GRANT EXECUTE ON OBJECT::dbo.xp_cmdshell TO [S11_ExportApplication];\n GRANT EXECUTE ON OBJECT::dbo.xp_fileexist TO [S11_ExportApplication];\n COMMIT TRANSACTION;\nEND TRY\nBEGIN CATCH\n IF XACT_STATE()<>0 ROLLBACK TRANSACTION;\n THROW;\nEND CATCH;';"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def require_prior(prior):
    if (
        prior.get("outcome") != "passed"
        or prior.get("first_failure") is not None
        or prior.get("cleanup_failures") != []
        or prior.get("login_disabled") is not True
        or prior.get("admin_connections_closed") != 1
        or prior.get("before") != prior.get("after")
        or prior.get("master_before") != prior.get("master_after")
        or prior.get("application_reader", {}).get("connections")
        != [dict(closed=True, close_failed=False)]
    ):
        raise ValueError("Exact settled privilege diagnostic required")


def require_master_state(before, after):
    from copy import deepcopy

    old = before["principals"]
    if len(old) != 1 or old[0]["principal_id"] != 7:
        raise ValueError("Exact original master user required")
    retained_name = "S11_ExportApplication_Retained_P02_20261120"
    retained = [row for row in after["principals"] if row["name"] == retained_name]
    if retained != [dict(old[0], name=retained_name)]:
        raise ValueError("Original master user was not preserved exactly")
    new = [row for row in after["principals"] if row["name"] == "S11_ExportApplication"]
    if (
        len(after["principals"]) != 2
        or len(new) != 1
        or type(new[0]["principal_id"]) is not int
        or new[0]["principal_id"] <= 0
        or new[0]["principal_id"] == 7
        or {k: v for k, v in new[0].items() if k != "principal_id"}
        != dict(
            name="S11_ExportApplication",
            type_desc="SQL_USER",
            default_schema_name="dbo",
            sid="4cd6a8a024f24341accad859487b5075",
        )
    ):
        raise ValueError("New master user mapping differs")

    def encode(row):
        return json.dumps(row, sort_keys=True)

    for name, field in (("grants", "principal"), ("ownership", "name")):
        expected = deepcopy(before[name])
        expected += [dict(row, **{field: retained_name}) for row in before[name]]
        if sorted(map(encode, after[name])) != sorted(map(encode, expected)):
            raise ValueError("Master grants or ownership differ")
    if after["memberships"] != before["memberships"] or after["memberships"]:
        raise ValueError("Unexpected master role membership")


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or manifest["purpose"] != "missing-master-mapping-and-three-contract-read"
        or manifest["production_eligible"] is not False
    ):
        raise ValueError("Exact isolated privilege reader required")
    for name, digest in manifest["files"].items():
        member = (packet / name).resolve()
        if not member.is_relative_to(packet) or sha(member.read_bytes()) != digest:
            raise ValueError("Sealed privilege reader changed")
    raw = (packet / "evidence/privilege-diagnostic.json").read_bytes()
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
    import application_privileges as audit
    import pyodbc
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    pyodbc.pooling = False
    receipt = dict(
        schema="p02-master-mapping-three-contract-proof/1",
        stage="master mapping preflight",
        outcome="running",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        cleanup_failures=[],
        setup_replayed=False,
        migration_replayed=False,
        restore_replayed=False,
        production_operations=0,
        business_operations=0,
        master_mapping_attempted=False,
        master_mapping_committed=False,
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
        if value["logins"] != prior["after"]["logins"] or value["server_roles"]:
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
        receipt["master_before"] = {name: read(sql) for name, sql in audit.MASTER.items()}
        if json.loads(json.dumps(receipt["before"], default=str)) != prior["after"]:
            raise ValueError("Complete retained administrative state changed")
        if receipt["master_before"] != prior["master_after"]:
            raise ValueError("Recorded master mapping changed")
        credential = manifest["credential"]
        if credential["path"] != control.CREDENTIAL_PATH:
            raise ValueError("Exact original guest credential required")
        encrypted = Path(control.CREDENTIAL_PATH).read_bytes()
        if sha(encrypted) != credential["sha256"]:
            raise ValueError("Original guest-only credential changed")
        password = control.unprotect(encrypted)
        candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
        receipt["stage"] = "apply missing master user mapping"
        receipt["master_mapping_attempted"] = True
        save()
        read(MASTER_SETUP)
        receipt["master_mapping_committed"] = True
        save()
        receipt["mapped_master"] = {name: read(sql) for name, sql in audit.MASTER.items()}
        require_master_state(receipt["master_before"], receipt["mapped_master"])
        receipt["stage"] = "three contract comparison"
        enable_attempted = True
        read(control.ENABLE)
        actual = control.run_contracts(
            lambda: pyodbc.connect(
                base
                + f"UID={control.PRINCIPAL};PWD={{{password}}};APP=P02ThreeContractsAfterMaster;",
                autocommit=True,
                timeout=3,
            ),
            candidate,
            manifest["release"],
            receipt,
        )
        receipt["contracts_verified"] = True
        password = None
        with (packet / "combined-observation.json").open("x", encoding="utf-8") as stream:
            json.dump(actual, stream, indent=2, default=str)
        receipt["outcome"] = "passed"
    except BaseException as error:
        receipt["outcome"] = "failed"
        receipt["first_failure"] = dict(stage=receipt["stage"], **sql_error_facts(error))
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
                    receipt["master_after"] = {
                        name: read(sql) for name, sql in audit.MASTER.items()
                    }
                    if receipt["after"] != receipt["before"] or read(control.SESSIONS):
                        raise ValueError("Retained database state or application closure differs")
                    if receipt["master_mapping_committed"]:
                        require_master_state(receipt["master_before"], receipt["master_after"])
                    elif receipt["master_after"] != receipt["master_before"]:
                        raise ValueError("Unacknowledged master mapping requires reconciliation")
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
