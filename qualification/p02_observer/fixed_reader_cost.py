"""Repeat the actual fixed contract reader with source comparison and row parity.

One warmup and five measurements, then the independent reader orders share the
same sealed run. No setup, migration, provider, or business operation is issued.
"""

import json
from pathlib import Path
import time


def qualify(connect, approved, expected, receipt, save, *, clock=time.monotonic):
    from independent_readers import encode, sha

    from scripts.verify_k98_running_release import ObservationConnections
    from services.export_execution_dal import ExportExecutionDAL, installation_migrations
    from services.export_runtime_composition import verify_installation_contract

    started = clock()
    group = receipt["fixed_reader_repeats"] = dict(
        warmups=1, measurements=5, samples=[], batch_cost_passed=True
    )
    for index in range(6):
        if clock() - started >= 60:
            raise TimeoutError("Fixed-reader group deadline reached; no further read started")
        owner = ObservationConnections(connect)
        sample = dict(index=index, warmup=index == 0, outcome="running")
        group["samples"].append(sample)
        save()
        before = clock()
        try:
            with owner:
                owner.observation_phase("export")
                actual = ExportExecutionDAL(owner).installation_snapshot(
                    migrations=installation_migrations(approved)
                )
                verify_installation_contract(actual, approved)
                sample["value_sha256"] = sha(encode(actual))
                if sample["value_sha256"] != expected:
                    raise ValueError("Complete fixed observation differs from retained native rows")
            sample["outcome"] = "passed"
        finally:
            sample["seconds"] = clock() - before
            sample["reader"] = owner.evidence()
            save()
        statements = sample["reader"]["statements"]
        sample["maximum_batch_seconds"] = max(
            s["execute_seconds"] + s["fetch_seconds"] for s in statements
        )
        sample["batch_cost_passed"] = sample["maximum_batch_seconds"] <= 0.250
        group["batch_cost_passed"] &= sample["batch_cost_passed"]
        save()
    group["seconds"] = clock() - started
    return group


def run(packet, manifest, receipt, save):
    from independent_readers import sha
    import pyodbc
    import three_contracts as control

    credential = manifest["credential"]
    if credential["path"] != control.CREDENTIAL_PATH:
        raise ValueError("Original guest credential path required")
    raw = Path(credential["path"]).read_bytes()
    if sha(raw) != credential["sha256"]:
        raise ValueError("Guest credential identity changed")
    password = control.unprotect(raw)
    candidate = json.loads((packet / "candidate-contracts.json").read_bytes())

    def connect():
        return pyodbc.connect(
            "DRIVER={ODBC Driver 18 for SQL Server};SERVER=lpc:localhost;"
            "DATABASE=ROK_TRACKER;Encrypt=yes;TrustServerCertificate=yes;"
            f"UID={control.PRINCIPAL};PWD={{{password}}};APP=P02FixedReaderCost;",
            autocommit=True,
            timeout=3,
        )

    try:
        return qualify(
            connect,
            candidate["sql_contract"],
            manifest["retained_fixed_value_sha256"],
            receipt,
            save,
        )
    finally:
        password = None
