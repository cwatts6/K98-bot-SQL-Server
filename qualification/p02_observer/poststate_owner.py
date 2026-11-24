"""Physical name ownership for one acknowledged new L1 fixture, never claim recovery."""

from contextlib import contextmanager
from copy import deepcopy
from datetime import datetime, timedelta
import json
from pathlib import Path
import re
from uuid import UUID

from fresh_business_state import CLOCK, DATABASES, IDENTITY, normalized, require_identity

NAMES = ()

IDS = (18, 27)
GUIDS = {
    18: "9dc35927-02a8-4c11-bc05-210381eca28d",
}
FILES = """SELECT database_id,file_id,name,physical_name,type_desc,
CONVERT(varchar(36),file_guid) AS file_guid FROM sys.master_files
WHERE database_id IN (16,18,23,24,25,26,27) ORDER BY database_id,file_id"""
SESSIONS = """SELECT s.session_id,s.login_name,s.database_id,r.database_id AS request_database,
s.open_transaction_count FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_requests r ON r.session_id=s.session_id
WHERE s.is_user_process=1 AND s.session_id<>@@SPID AND
(s.database_id IN (16,18,23,24,25,26,27) OR r.database_id IN (16,18,23,24,25,26,27)
OR s.login_name IN (N'S11_ExportApplication',N'S11_ExportApplication_Retained_P02_20261120'))"""
LOCKS = """SELECT request_session_id,resource_database_id,resource_type,request_status
FROM sys.dm_tran_locks WHERE resource_database_id IN (16,18,23,24,25,26,27)
AND request_session_id<>@@SPID AND request_session_id>0"""


def bind_fixture(packet, manifest, binding_sha256):
    import hashlib

    global NAMES
    if NAMES or 27 in GUIDS:
        raise ValueError("Fresh fixture may be bound only once in this process")
    from poststate_chain import fixture_stamp

    stamp = fixture_stamp(manifest)
    raw = (packet / "restore-bindings.json").read_bytes()
    if (
        not re.fullmatch(r"[0-9]{17}", stamp)
        or manifest.get("purpose") != "p02-poststate-capture-chain"
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or hashlib.sha256(raw).hexdigest() != binding_sha256
        or manifest.get("databases") != ["K98_P02CaptureChain_" + stamp]
    ):
        raise ValueError("Exact newly acknowledged capture-chain binding required")
    values = json.loads(raw)["fixtures"]
    if len(values) != 1:
        raise ValueError("One new capture-chain fixture required")
    item = values[0]
    if (
        item["database_id"] != 27
        or item["name"] != manifest["databases"][0]
        or item["family_guid"].lower() != "c4de892e-fd68-46e4-ab63-245e74bfc07b"
        or Path(item["data"]) != Path(manifest["data_directory"]) / "CHAIN.mdf"
        or Path(item["log"]) != Path(manifest["data_directory"]) / "CHAIN.ldf"
    ):
        raise ValueError("Restore acknowledgement is outside the single new fixture")
    identity = str(UUID(item["database_guid"]))
    if identity in GUIDS.values():
        raise ValueError("Fresh fixture cannot replace original database lineage")
    GUIDS[27] = identity
    NAMES = (item["name"],)
    return item


def park_name(manifest):
    stamp = Path(manifest["guest_directory"]).name
    if not re.fullmatch(r"[0-9]{17}", stamp):
        raise ValueError("Exact sealed packet stamp required")
    return "K98_P02Capture_Preserved_" + stamp


def transition(before, after, action, files_before, files_after):
    """Only an acknowledged exact name/access transition can update expectations."""
    if files_before != files_after or len(before) != len(after):
        raise ValueError("Physical database inventory or file identity changed")
    number = action["database_id"]
    if number not in IDS or action["acknowledged"] is not True:
        raise ValueError("Acknowledged capture name owner required")
    wanted = deepcopy(before)
    row = next(r for r in wanted if r["database_id"] == number)
    actual = next(r for r in after if r["database_id"] == number)
    if str(row["database_guid"]).lower() != GUIDS[number]:
        raise ValueError("Physical database lineage changed")
    if action["kind"] == "rename":
        if row["name"] != action["from"]:
            raise ValueError("Name transition did not start from its recorded predecessor")
        old, new = datetime.fromisoformat(row["create_date"]), datetime.fromisoformat(
            actual["create_date"]
        )
        start, end = (datetime.fromisoformat(action[k]) for k in ("before", "after"))
        if new != old and not start - timedelta(milliseconds=4) <= new <= end + timedelta(
            milliseconds=4
        ):
            raise ValueError("Rename date lacks its original acknowledged boundary")
        row.update(name=action["to"], create_date=actual["create_date"])
    elif action["kind"] == "access" and number in (27,):
        if action["from"] != row["user_access_desc"] or action["to"] not in (
            "MULTI_USER",
            "RESTRICTED_USER",
        ):
            raise ValueError("Unexpected new-copy access transition")
        row["user_access_desc"] = action["to"]
    else:
        raise ValueError("Unsupported physical transition")
    if wanted != after:
        raise ValueError("Database changed outside the acknowledged transition")
    return wanted


@contextmanager
def owned(database, record, save, *, timeout=3):
    from fresh_business_owner import HELD, SqlOwner
    import pyodbc

    if database not in ("master", "ROK_TRACKER", *NAMES):
        raise ValueError("Only master and the exact capture fixture may be opened")
    owner = SqlOwner.__new__(SqlOwner)
    owner.record, owner.save, owner.cursors = record, save, []
    owner.connection, owner.close_attempted = None, False
    owner.connection = pyodbc.connect(
        "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;DATABASE="
        + database
        + ";Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;APP=P02CaptureChain;",
        autocommit=True,
        timeout=3,
    )
    HELD.append(owner)
    owner.connection.timeout = timeout
    first = None
    try:
        yield owner
    except BaseException as error:
        first = error
        raise
    finally:
        try:
            owner.close()
        except BaseException as error:
            record["cleanup_failures"].append(
                dict(operation="cost owner close", error_type=type(error).__name__)
            )
            if first is None:
                raise


class NameOwner:
    def __init__(self, manifest, record, save):
        if len(NAMES) != 1 or 27 not in GUIDS:
            raise ValueError("New fixture identity must be acknowledged before name ownership")
        self.manifest, self.record, self.save = manifest, record, save
        self.current = None
        self.files = None
        self.uncertain = False
        self.park = park_name(manifest)
        record["name_transitions"] = []

    def inventory(self, owner):
        from fixed_contract_cost import SERVICES_SQL
        from fresh_business import require_login
        from restart_read import require_services

        require_identity(owner.read(IDENTITY), "master", 1)
        require_login(owner.read)
        require_services(owner.read(SERVICES_SQL))
        if owner.read(SESSIONS) or owner.read(LOCKS):
            raise ValueError("Foreign activity prevents capture name handover")
        rows = normalized(owner.read(DATABASES))
        files = normalized(owner.read(FILES))
        if self.current is not None and (rows != self.current or files != self.files):
            raise ValueError("Name owner predecessor or physical files changed")
        for number in IDS:
            row = next(r for r in rows if r["database_id"] == number)
            if str(row["database_guid"]).lower() != GUIDS[number]:
                raise ValueError("Exact physical capture/original database required")
        return rows, files

    def begin(self):
        with owned("master", self.record, self.save) as owner:
            rows, files = self.inventory(owner)
        names = {r["database_id"]: r["name"] for r in rows}
        if (
            names.get(18) != "ROK_TRACKER"
            or [names.get(n) for n in (27,)] != list(NAMES)
            or self.park in names.values()
        ):
            raise ValueError("Unstarted capture name handover required")
        self.current, self.files = rows, files
        self.record["name_inventory_before"] = rows
        self.record["name_files"] = files
        self.change(18, "rename", self.park)

    def change(self, number, kind, target):
        from fresh_business_owner import HELD

        if self.uncertain or HELD or number not in IDS:
            raise ValueError("Unresolved physical ownership prevents another name transition")
        allowed = {
            18: ("ROK_TRACKER", self.park),
            27: ("ROK_TRACKER", NAMES[0]),
        }
        with owned("master", self.record, self.save) as owner:
            before, files = self.inventory(owner)
            row = next(r for r in before if r["database_id"] == number)
            if kind == "rename" and target in allowed[number] and row["name"] in allowed[number]:
                if any(r["name"] == target for r in before):
                    raise ValueError("Destination name is already owned")
                statement = "ALTER DATABASE [" + row["name"] + "] MODIFY NAME = [" + target + "];"
                source = row["name"]
            elif (
                kind == "access" and number in (27,) and target in ("MULTI_USER", "RESTRICTED_USER")
            ):
                statement = "ALTER DATABASE [" + row["name"] + "] SET " + target + ";"
                source = row["user_access_desc"]
                if source == target:
                    raise ValueError("Access transition already completed; no replay")
            else:
                raise ValueError("Unsupported name handover")
            action = dict(
                kind=kind, database_id=number, **{"from": source, "to": target}, acknowledged=False
            )
            action["before"] = str(owner.read(CLOCK)[0]["local_time"])
            self.record["name_transitions"].append(action)
            self.uncertain = True
            self.save()
            owner.mutate("capture " + kind + " DB" + str(number), statement)
            action["acknowledged"] = True
            action["after"] = str(owner.read(CLOCK)[0]["local_time"])
            after = normalized(owner.read(DATABASES))
            current_files = normalized(owner.read(FILES))
            self.current = transition(before, after, action, files, current_files)
            self.record["name_inventory_current"] = self.current
            self.uncertain = False
            self.save()

    def activate(self, number):
        if number not in (27,):
            raise ValueError("Only the new acknowledged copy may run business")
        if any(r["name"] == "ROK_TRACKER" for r in self.current):
            raise ValueError("Previous canonical owner has not settled")
        self.change(number, "rename", "ROK_TRACKER")
        self.change(number, "access", "MULTI_USER")

    def park_active(self):
        row = next((r for r in self.current if r["name"] == "ROK_TRACKER"), None)
        if row is not None:
            if row["database_id"] not in (27,):
                raise ValueError("Only an active capture copy can be parked")
            if row["user_access_desc"] == "MULTI_USER":
                self.change(row["database_id"], "access", "RESTRICTED_USER")
            self.change(row["database_id"], "rename", NAMES[0])

    def restore_original(self):
        self.park_active()
        self.change(18, "rename", "ROK_TRACKER")
        self.record["name_inventory_after"] = self.current
        self.record["original_name_restored"] = True
        self.save()


def adjusted_preservation(expected, names):
    """Carry only the verified DB18 rename date into existing strict readers."""
    latest, prior, old_manifest = deepcopy(expected)
    date = next(r["create_date"] for r in names.current if r["database_id"] == 18)
    for row in latest["databases_after"]:
        if row["database_id"] == 18:
            row["create_date"] = date
    targets = prior["fresh_before"]["target"]
    if len(targets) != 1 or targets[0]["database_id"] != 18:
        raise ValueError("Exact retained DB18 target required")
    targets[0]["create_date"] = date
    return latest, prior, old_manifest
