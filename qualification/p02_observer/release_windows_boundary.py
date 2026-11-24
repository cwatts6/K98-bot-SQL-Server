"""Native protected-file boundary qualification; never a deployable seed."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def expected_bytes(manifest):
    return json.dumps(
        {
            "schema": "p02-protected-io/1",
            "packet": manifest["guest_directory"],
            "prior_receipt_sha256": manifest["prior_sha256"],
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode()


def root_path(manifest):
    stamp = Path(manifest["guest_directory"]).name
    if len(stamp) != 17 or not stamp.isdecimal():
        raise ValueError("Exact fixture stamp required")
    expected = Path(r"C:\Program Files") / ("K98-P02-" + stamp)
    if str(expected) != manifest["boundary_directory"]:
        raise ValueError("Exact new protected fixture path required")
    return expected


def prepare(manifest, record, save):
    import pywintypes
    import win32file
    import win32security

    from core.export_execution_host import HostBoundaryError, current_sid
    from core.export_startup_windows import _attributes, administrative_path
    from scripts.prepare_k98_update import output_writers

    root = root_path(manifest)
    record.update(directory=str(root), stage="before exclusive root creation", outcome="running")
    save()
    if root.exists():
        raise ValueError("Existing protected fixture must not be replayed")
    administrative_path(root.parent, private=False)
    sid = current_sid()
    # Only the fresh leaf receives an ACL. Existing Program Files/fixtures
    # retain their ownership and permissions.
    win32file.CreateDirectory(str(root), _attributes(sid, directory=True))
    record.update(root_created=True, stage="private root created")
    save()
    administrative_path(root, private=True)
    mkdir, write = output_writers(sid, secure_output=True)
    directory = root / "io"
    mkdir(directory)
    target = directory / "proof.json"
    raw = expected_bytes(manifest)
    write(target, raw)
    administrative_path(target, private=True)
    if target.read_bytes() != raw:
        raise ValueError("Protected write/readback differs")
    record.update(proof_committed=True, stage="protected proof written and read back")
    save()
    try:
        write(target, b"different non-secret qualification bytes")
    except pywintypes.error as error:
        if error.winerror not in (80, 183):
            raise
        replacement_refused = True
    else:
        raise ValueError("Exclusive protected creation allowed replacement")
    if target.read_bytes() != raw:
        raise ValueError("Existing protected proof changed")

    # A separate non-secret negative fixture, under the private parent. Never
    # weaken the accepted proof's ACL or any existing file/directory.
    rejected = directory / "public-probe.json"
    attrs = pywintypes.SECURITY_ATTRIBUTES()
    attrs.SECURITY_DESCRIPTOR = win32security.ConvertStringSecurityDescriptorToSecurityDescriptor(
        "O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;WD)", 1
    )
    attrs.bInheritHandle = False
    handle = win32file.CreateFile(str(rejected), 0x40000000, 0, attrs, 1, 0x80000000, None)
    try:
        win32file.WriteFile(handle, b"non-secret ACL refusal fixture")
        win32file.FlushFileBuffers(handle)
    finally:
        handle.Close()
    try:
        administrative_path(rejected, private=True)
    except HostBoundaryError as error:
        if str(error) != "Untrusted authority path access.":
            raise
        public_read_refused = True
    else:
        raise ValueError("Broad-read private evidence was accepted")
    administrative_path(target, private=True)
    record.update(
        outcome="passed",
        stage="protected IO checks passed",
        directory=str(root),
        sid=sid,
        proof_sha256=hashlib.sha256(raw).hexdigest(),
        replacement_refused=replacement_refused,
        public_read_refused=public_read_refused,
        existing_acls_changed=False,
        provider_work=False,
    )
    save()
    return record


def restart_read(manifest):
    from core.export_startup_windows import administrative_path

    target = root_path(manifest) / "io/proof.json"
    administrative_path(target, private=True)
    raw = target.read_bytes()
    if raw != expected_bytes(manifest):
        raise ValueError("Retained protected bytes differ after restart")
    return dict(
        outcome="passed",
        pid=os.getpid(),
        proof_sha256=hashlib.sha256(raw).hexdigest(),
        protected_read_passed=True,
        provider_work=False,
    )


def run_restart(
    packet, manifest, record, save, *, launch=None, clock=time.monotonic, wait=time.sleep
):
    handles = []
    process = None
    first = None
    started = clock()
    try:
        if launch is None:
            for name in ("boundary-child-stdout.txt", "boundary-child-stderr.txt"):
                handles.append((packet / name).open("xb"))
            env = {
                k: v
                for k, v in os.environ.items()
                if k not in ("S11_SQL_PASSWORD", "SQL_PASSWORD", "IMPORT_SQL_PASSWORD")
            }
            process = subprocess.Popen(
                [
                    sys.executable,
                    "-I",
                    "-S",
                    "-B",
                    str(packet / "qualification/p02_observer/application.py"),
                    "--boundary-read",
                ],
                cwd=packet,
                env=env,
                stdout=handles[0],
                stderr=handles[1],
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
        else:
            process, handles = launch()
        record["child_pid"] = process.pid
        save()
        while process.poll() is None:
            if clock() - started >= 30:
                first = TimeoutError("Original protected-read child retained after deadline")
                record["child_retained_running"] = True
                save()
                break
            wait(0.1)
    except BaseException as error:
        first = error
    finally:
        try:
            if process is not None:
                while process.poll() is None:
                    record["child_retained_running"] = True
                    save()
                    wait(1)
                process.wait()
                record["child_exit_code"] = process.returncode
                record["child_settled"] = True
        except BaseException as error:
            if first is None:
                first = error
        finally:
            for handle in handles:
                try:
                    handle.close()
                except BaseException as error:
                    record.setdefault("child_io_cleanup_errors", []).append(type(error).__name__)
                    if first is None:
                        first = error
    if first is not None:
        raise first
    value = json.loads((packet / "stage-2.json").read_bytes())
    if (
        process.returncode != 0
        or value.get("outcome") != "passed"
        or value.get("pid") != process.pid
        or process.pid == os.getpid()
        or value.get("proof_sha256") != record["proof_sha256"]
        or value.get("protected_read_passed") is not True
    ):
        raise ValueError("Independent protected read or child identity failed")
    record["restart_read"] = value
    return value
