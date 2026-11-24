"""One retained, non-replaying native owner for the remaining capture-chain group."""

from datetime import UTC, datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PURPOSE = "p02-poststate-capture-chain"


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def capture_cases(manifest):
    route = manifest.get("capture_route")
    if route == "player_report":
        import poststate_report_cases

        return poststate_report_cases
    if route == "all_kvk":
        import poststate_cases

        return poststate_cases
    raise ValueError("Explicit reviewed capture route required")


def fixture_stamp(manifest):
    continuation = manifest.get("continuation")
    if continuation is None:
        return Path(manifest["guest_directory"]).name
    if continuation not in (
        "status-before-preflight-20261123150616134",
        "installed-publisher-refused-20261123160455336",
        "captured-index-diagnosed-20261123170039650",
    ):
        raise ValueError("Only the exact retained capture continuation is supported")
    return "20261123150616134"


def require_packet(packet, manifest):
    if manifest.get("capture_route") not in ("player_report", "all_kvk"):
        raise ValueError("Explicit reviewed capture route required")
    stamp = packet.name
    fixture_id = fixture_stamp(manifest)
    if (
        os.environ.get("COMPUTERNAME") != "MINI_AMD"
        or not re.fullmatch(r"[0-9]{17}", stamp)
        or packet != Path(manifest["guest_directory"])
        or manifest.get("purpose") != PURPOSE
        or manifest.get("production_eligible") is not False
        or manifest.get("vm_id") != "2ac1b401-7076-4965-af71-de36ee0f9f9c"
        or manifest.get("databases") != ["K98_P02CaptureChain_" + fixture_id]
        or manifest.get("new_disk_bytes") != (0 if manifest.get("continuation") else 192 * 1024**3)
        or manifest.get("drive_letter") != "T"
        or manifest.get("data_directory") != "T:\\P02Capture_" + fixture_id
    ):
        raise ValueError("Exact sealed capture-chain packet required")
    for name, digest in manifest["files"].items():
        source = (packet / name).resolve()
        if not source.is_relative_to(packet) or sha(source.read_bytes()) != digest:
            raise ValueError("Sealed capture-chain member differs")


def protected_verifier(packet, manifest, record):
    from core.export_execution_host import current_sid
    from core.export_startup_windows import administrative_path
    from scripts.prepare_k98_update import output_writers

    root = Path(manifest["private_directory"]) / "verifier"
    mkdir, write = output_writers(current_sid(), secure_output=True)
    mkdir(root)
    old = packet / "verifier"
    raw = (old / "update-tool.json").read_bytes()
    if sha(raw) != manifest["verifier_manifest_sha256"]:
        raise ValueError("Exact final verifier package required")
    value = json.loads(raw)
    for name, digest in value["files"].items():
        content = (old / name).read_bytes()
        if Path(name).name != name or sha(content) != digest:
            raise ValueError("Final verifier inventory differs")
        write(root / name, content)
        administrative_path(root / name, private=True)
    write(root / "update-tool.json", raw)
    administrative_path(root / "update-tool.json", private=True)
    record["protected_verifier"] = dict(
        path=str(root), manifest_sha256=sha(raw), members=len(value["files"])
    )


def activate_tool(manifest):
    # Select the protected exact package before any application module is imported.
    root = Path(manifest["private_directory"]) / "verifier"
    raw = (root / "update-tool.json").read_bytes()
    if sha(raw) != manifest["verifier_manifest_sha256"]:
        raise ValueError("Protected verifier manifest differs")
    value = json.loads(raw)
    source = root / "verify_k98_update_pair.py"
    if sha(source.read_bytes()) != value["files"][source.name]:
        raise ValueError("Protected verifier executable differs")
    spec = importlib.util.spec_from_file_location("scripts.verify_k98_update_pair", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.modules[spec.name] = module
    module.activate_contract_archive(
        root / "contract_verifier.zip",
        value["files"]["contract_verifier.zip"],
        Path(manifest["guest_directory"]) / "bot",
    )
    from core.export_startup_windows import administrative_path

    for name, digest in value["files"].items():
        target = administrative_path(root / name, private=True)
        if sha(target.read_bytes()) != digest:
            raise ValueError("Protected final verifier changed before observation")
    return dict(
        manifest_sha256=sha(raw),
        archive_sha256=value["files"]["contract_verifier.zip"],
        reader=str(source),
    )


def role(packet, manifest, binding_sha, kind):
    tool = activate_tool(manifest) if kind == "tool" else None
    from cost_execution import blank, writer
    from fresh_business_owner import HELD
    from independent_readers import write_new
    import poststate_owner
    from producer_runtime import Connections, application_credentials

    from scripts.verify_k98_running_release import sql_error_facts

    poststate_owner.bind_fixture(packet, manifest, binding_sha)
    root = packet / ("chain-" + kind)
    root.mkdir(exist_ok=False)
    record = blank("fresh " + kind + " role")
    record.update(pid=os.getpid(), role=kind, provider_operations=0, production_operations=0)
    save = writer(root, record)
    write_new(root / "entered.json", dict(pid=os.getpid(), role=kind))
    connections = Connections()
    safe = False
    try:
        with application_credentials(manifest):
            if kind == "workload":
                capture_cases(manifest).run(packet, manifest, record, save, connections)
            elif kind == "consumer":
                capture_cases(manifest).consume(packet, manifest, record, save, connections)
            elif kind == "tool":
                import three_contracts

                candidate = json.loads((packet / "candidate-contracts.json").read_bytes())
                try:
                    result = three_contracts.run_contracts(
                        connections, candidate, manifest["release"], record
                    )
                finally:
                    write_new(packet / "protected-tool-observation.json", record)
                record["tool"] = tool
                from core.recovery_sql_snapshot import require_recovery_snapshot_isolation
                from services.application_observation_schedule import read_owned_observation

                read_owned_observation(connections, require_recovery_snapshot_isolation)
                record.update(
                    three_contracts_verified=True,
                    startup_recovery_isolation_verified=True,
                    actual_observation_sha256=sha(
                        json.dumps(result, sort_keys=True, default=str).encode()
                    ),
                    full_startup_runtime_qualified=False,
                    business_operations=0,
                )
            else:
                raise ValueError("Unknown declared role")
        record.update(outcome="passed", stage=kind + " checks completed")
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        record["application_cleanup"] = dict(safe_to_exit=False, all_closed_by_callers=False)
        try:
            record["application_cleanup"] = connections.finish()
        except BaseException as error:
            record["cleanup_failures"].append(
                dict(operation="application physical close", **sql_error_facts(error))
            )
        safe = not HELD and record["application_cleanup"]["safe_to_exit"]
        if (
            not safe
            or not record["application_cleanup"]["all_closed_by_callers"]
            or record["cleanup_failures"]
        ):
            record["outcome"] = "failed"
        record.update(
            physical_custody_retained=not safe,
            credential_environment_cleared="S11_SQL_PASSWORD" not in os.environ,
            finished=datetime.now(UTC).isoformat(),
        )
        try:
            save()
            write_new(root / "receipt.json", record)
        finally:
            # Evidence storage failure cannot terminate an uncertain physical owner.
            while not safe:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def launch(packet, manifest, binding_sha, kind, record, save):
    from fresh_business_owner import HELD

    if kind not in ("workload", "tool", "consumer") or HELD:
        raise ValueError("A fresh declared role requires settled predecessor ownership")
    item = dict(role=kind, acknowledged=False, settled=False)
    record["children"].append(item)
    save()
    handles = []
    child = None
    try:
        for stream in ("stdout", "stderr"):
            handles.append((packet / ("chain-" + kind + "." + stream + ".txt")).open("xb"))
        env = {
            k: v
            for k, v in os.environ.items()
            if k not in ("S11_SQL_PASSWORD", "SQL_PASSWORD", "IMPORT_SQL_PASSWORD")
        }
        child = subprocess.Popen(
            [sys.executable, "-I", "-S", "-B", str(Path(__file__)), "--role", kind, binding_sha],
            cwd=packet,
            env=env,
            stdout=handles[0],
            stderr=handles[1],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        HELD.append(child)
        child._p02_output_handles = handles
        item["pid"] = child.pid
        save()
        started = time.monotonic()
        limit = 600 if kind == "workload" else 150
        while child.poll() is None and time.monotonic() - started < limit:
            time.sleep(1)
        if child.poll() is None:
            raise TimeoutError("Original capture-chain child remains owned; no successor or replay")
        child.wait()
        HELD.remove(child)
        item.update(settled=True, exit_code=child.returncode, seconds=time.monotonic() - started)
        for handle in handles:
            handle.close()
        handles.clear()
        path = packet / ("chain-" + kind) / "receipt.json"
        raw = path.read_bytes()
        value = json.loads(raw)
        item.update(receipt=str(path.relative_to(packet)), receipt_sha256=sha(raw))
        save()
        if (
            child.returncode != 0
            or value.get("outcome") != "passed"
            or value.get("first_failure")
            or value.get("cleanup_failures")
            or value.get("physical_custody_retained") is not False
            or value.get("credential_environment_cleared") is not True
        ):
            raise ValueError("Original " + kind + " role failed; preserve its exact result")
        item["acknowledged"] = True
        save()
        return value
    finally:
        if child is None or child.poll() is not None:
            for handle in handles:
                handle.close()


def parent(packet, manifest, binding_sha):
    from cost_execution import blank, writer
    from fresh_business import require_login
    from fresh_business_owner import HELD
    from fresh_business_state import DATABASES, IDENTITY, normalized, require_identity
    from independent_readers import write_new
    import poststate_owner as owner_control
    import poststate_preservation as preservation
    import poststate_release as release
    from producer_capture import dependency_preflight, private_spool
    import three_contracts as control

    from scripts.verify_k98_running_release import sql_error_facts

    fixture = owner_control.bind_fixture(packet, manifest, binding_sha)
    record = blank("authenticate restored capture-chain fixture")
    record.update(
        workload_copies=[],
        children=[],
        coordinator=[],
        production_operations=0,
        provider_operations=0,
        original_preserved=False,
        original_name_restored=False,
        login_disabled=None,
    )
    root = packet / "integration"
    root.mkdir(exist_ok=False)
    save = writer(root, record)
    write_new(root / "entered.json", dict(pid=os.getpid(), purpose=PURPOSE))
    names = None
    previous_names = None
    ctx = None
    login_attempted = False
    safe = False
    try:
        ctx = preservation.context(packet)
        retained = None
        previous_names = None
        if manifest.get("continuation"):
            if manifest["continuation"] == "captured-index-diagnosed-20261123170039650":
                import poststate_captured as poststate_continue
            elif manifest["continuation"] == "installed-publisher-refused-20261123160455336":
                import poststate_installed as poststate_continue
            else:
                import poststate_continue

            retained = poststate_continue.authenticate(packet, manifest)
            previous_names = poststate_continue.previous_names(retained)
            record["retained_setup"] = dict(
                receipt_sha256=poststate_continue.PINS["integration/receipt.json"],
                storage_and_restore_replayed=False,
                backups_replayed=False,
            )
        with owner_control.owned("master", record, save) as owner:
            current = normalized(owner.read(DATABASES))
        row = next(r for r in current if r["database_id"] == 27)
        if (
            row["name"] != fixture["name"]
            or row["database_guid"].lower() != fixture["database_guid"].lower()
        ):
            raise ValueError("Original restore identity changed")
        if retained is not None:
            poststate_continue.verify_retained(record, save, manifest, retained, current)
        record["before"] = preservation.observe(
            packet, record, save, ctx, fixture=row, acknowledged_names=previous_names
        )
        record["dependencies"] = dependency_preflight()
        if retained is not None and "capture" in retained:
            poststate_continue.verify_private(packet, manifest, record, retained)
        else:
            record["private_spool"] = private_spool(manifest)
            protected_verifier(packet, manifest, record)
        save()
        names = owner_control.NameOwner(manifest, record, save)
        names.begin()
        names.activate(27)
        if retained is None:
            release.backups(packet, manifest, record, save, names)
        if retained is not None and "installed" in retained:
            observed = release.coordinator(packet, manifest, "Verify", record, save)
            if observed != retained["installed"]:
                raise ValueError("Committed observer identity changed; no successor work")
            record["observer_installation_replayed"] = False
        else:
            for operation in ("Status", "Preflight", "Apply", "Verify"):
                release.coordinator(packet, manifest, operation, record, save)
        with owner_control.owned("ROK_TRACKER", record, save) as owner:
            require_identity(owner.read(IDENTITY), "ROK_TRACKER", 27)
            from producer_fixture import ORIGINAL_PREPARATIONS

            record["original_preparations"] = owner.read(
                ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"]
            )
        with owner_control.owned("master", record, save) as owner:
            require_login(owner.read)
            login_attempted = True
            owner.mutate("enable existing login for new capture-chain fixture", control.ENABLE)
        for kind in ("workload", "tool", "consumer"):
            record["stage"] = "original " + kind + " process"
            save()
            launch(packet, manifest, binding_sha, kind, record, save)
        with owner_control.owned("ROK_TRACKER", record, save, timeout=15) as owner:
            from cost_resume import HISTORY, require_history
            from cost_workload import require_settled_capture_set
            from producer_fixture import FRESH_ACCOUNT, RESOURCE_SQL

            captures = json.loads((packet / "chain-captures.json").read_bytes())
            rows = owner.read(FRESH_ACCOUNT, manifest["account"])
            resources = owner.read(RESOURCE_SQL, "account:" + manifest["account"])
            require_settled_capture_set(rows, resources, captures)
            if (
                owner.read(ORIGINAL_PREPARATIONS, manifest["account"], manifest["account"])
                != record["original_preparations"]
            ):
                raise ValueError("Pre-existing fixture preparations changed")
            history = owner.read(HISTORY)
            baseline = json.loads((packet / "evidence/backup-baseline.json").read_bytes())[
                "history"
            ]
            require_history(history, baseline, "ON", record)
            record["new_fixture_settlement"] = dict(
                captures=normalized(rows),
                resources=normalized(resources),
                history=normalized(history),
                original_preparations_unchanged=True,
            )
        record.update(outcome="passed", stage="declared native capture/tool chain completed")
    except BaseException as error:
        record.update(
            outcome="failed", first_failure=dict(stage=record["stage"], **sql_error_facts(error))
        )
        if isinstance(error, ValueError):
            record["first_failure"]["detail"] = str(error)[:400]
    finally:
        safe = not HELD
        if login_attempted:
            try:
                with owner_control.owned("master", record, save) as owner:
                    owner.mutate("disable existing application login", control.DISABLE)
                    require_login(owner.read)
                record["login_disabled"] = True
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="disable login", **sql_error_facts(error))
                )
        if safe and names is not None and names.current is not None and not names.uncertain:
            try:
                names.restore_original()
            except BaseException as error:
                record["cleanup_failures"].append(
                    dict(operation="restore original name", **sql_error_facts(error))
                )
        if safe and ctx is not None and (names is None or record["original_name_restored"]):
            try:
                with owner_control.owned("master", record, save) as owner:
                    rows = normalized(owner.read(DATABASES))
                final = next(r for r in rows if r["database_id"] == 27)
                record["after"] = preservation.observe(
                    packet,
                    record,
                    save,
                    ctx,
                    fixture=final,
                    acknowledged_names=names or previous_names,
                )
                record.update(original_preserved=True, login_disabled=True, new_fixture=final)
            except BaseException as error:
                record["preservation_failure"] = sql_error_facts(error)
                record["outcome"] = "failed"
        safe = safe and not HELD
        if not safe or record["cleanup_failures"]:
            record["outcome"] = "failed"
        record.update(
            physical_custody_retained=not safe,
            name_transition_uncertain=names.uncertain if names else False,
            full_startup_runtime_qualified=False,
            production_release_accepted=False,
            finished=datetime.now(UTC).isoformat(),
        )
        try:
            save()
            write_new(root / "receipt.json", record)
        finally:
            # Evidence storage failure cannot terminate an uncertain physical owner.
            while not safe:
                time.sleep(1)
    return 0 if record["outcome"] == "passed" else 1


def main():
    packet = Path(__file__).resolve().parents[2]
    manifest = json.loads((packet / "manifest.json").read_bytes())
    require_packet(packet, manifest)
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from release_boundary import native_paths

    native_paths(packet)
    import pyodbc

    pyodbc.pooling = False
    if (
        len(sys.argv) == 4
        and sys.argv[1] == "--role"
        and sys.argv[2] in ("workload", "tool", "consumer")
    ):
        return role(packet, manifest, sys.argv[3], sys.argv[2])
    if len(sys.argv) != 2 or not re.fullmatch(r"[a-f0-9]{64}", sys.argv[1]):
        raise ValueError("Exact acknowledged restore-binding hash required")
    return parent(packet, manifest, sys.argv[1])


if __name__ == "__main__":
    raise SystemExit(main())
