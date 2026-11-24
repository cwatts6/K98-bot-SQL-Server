"""Own original report/reader child handles and record actual SQL-engine overlap."""

from datetime import UTC, datetime
import json
import os
import subprocess
import sys
import time

from independent_readers import query, write_new
from producer_fixture import ACTIVE_SQL
from producer_runtime import role_file


def signal(packet, manifest, child, suffix):
    value = dict(
        pid=child["process"].pid,
        role=child["role"],
        index=child["index"],
        packet=manifest["guest_directory"],
    )
    write_new(role_file(packet, child["role"], child["index"], suffix), value)
    child["signalled"] = suffix


def launch(packet, role, index):
    handles = []
    try:
        for stream in ("stdout", "stderr"):
            handles.append((packet / f"{role}-{index}.{stream}.txt").open("xb"))
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
                "--role",
                role,
                "--index",
                str(index),
            ],
            cwd=packet,
            env=env,
            stdout=handles[0],
            stderr=handles[1],
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
    except BaseException:
        for handle in handles:
            handle.close()
        raise
    return dict(process=process, handles=handles, role=role, index=index, signalled=None)


def wait_ready(packet, manifest, child, *, clock=time.monotonic, wait=time.sleep):
    started = clock()
    path = role_file(packet, child["role"], child["index"], "ready")
    while not path.exists():
        if child["process"].poll() is not None:
            raise ValueError("Original child exited before readiness")
        if clock() - started >= 65:
            raise TimeoutError("Original child readiness deadline; retain its custody")
        wait(0.05)
    value = json.loads(path.read_bytes())
    if any(
        value.get(k) != v
        for k, v in dict(
            pid=child["process"].pid,
            role=child["role"],
            index=child["index"],
            packet=manifest["guest_directory"],
        ).items()
    ):
        raise ValueError("Ready receipt belongs to another child")
    child["ready"] = value
    return value


def active(connection, children):
    pids = {c["process"].pid: c["role"] for c in children}
    if len(pids) != 2:
        raise ValueError("Two distinct actual child processes required")
    rows = query(connection, ACTIVE_SQL, *pids)
    if any(row["host_process_id"] not in pids for row in rows):
        raise ValueError("Observed SQL request belongs to another child")
    return rows


def overlap(rows, children):
    roles = {c["process"].pid: c["role"] for c in children}
    producer = [
        r for r in rows if roles.get(r["host_process_id"]) == "producer" and r["report_batch"]
    ]
    observer = [r for r in rows if roles.get(r["host_process_id"]) == "reader"]
    active_states = {"running", "runnable"}
    return bool(producer and observer), bool(
        any(r["request_status"] in active_states for r in producer)
        and any(r["request_status"] in active_states for r in observer)
    )


def settle(packet, manifest, children, record, save, *, wait=time.sleep):
    failures = []
    progress_failed = False
    # An observer waiting for a start can safely stop without any SQL work.
    for child in children:
        if (
            child["role"] == "reader"
            and child["signalled"] is None
            and child["process"].poll() is None
        ):
            try:
                signal(packet, manifest, child, "abort")
            except BaseException as error:
                failures.append(
                    dict(operation="unstarted reader signal", error_type=type(error).__name__)
                )
    for child in children:
        process = child["process"]
        while process.poll() is None:
            record["retained_running"] = [
                c["process"].pid for c in children if c["process"].poll() is None
            ]
            if not progress_failed:
                try:
                    save()
                except BaseException as error:
                    progress_failed = True
                    failures.append(
                        dict(operation="retained child progress", error_type=type(error).__name__)
                    )
            wait(1)
        process.wait()
        child["exit_code"] = process.returncode
        for handle in child["handles"]:
            try:
                handle.close()
            except BaseException as error:
                failures.append(
                    dict(operation="child output close", error_type=type(error).__name__)
                )
    record["settled"] = True
    record["retained_running"] = []
    record["cleanup_failures"] = failures
    return failures


def run_pair(packet, manifest, connection, index, record, save):
    from scripts.verify_k98_running_release import sql_error_facts

    children = []
    record.update(
        index=index,
        order="observer_first" if index == 1 else "producer_first",
        stage="launch independent reader",
        started=datetime.now(UTC).isoformat(),
        first_failure=None,
        settled=False,
        simultaneous_requests=False,
        simultaneous_running_or_runnable=False,
        samples=[],
        children=[],
    )
    first = None
    barrier = None

    def remember(child):
        children.append(child)
        record["children"].append(dict(role=child["role"], index=index, pid=child["process"].pid))
        save()

    try:
        observer = launch(packet, "reader", index)
        remember(observer)
        wait_ready(packet, manifest, observer)
        if manifest.get("controlled_report_barrier") is True:
            from report_barrier import ReportBarrier

            if index != 2 or manifest.get("prepared_reader") is not True:
                raise ValueError("Exact prepared producer-first control required")
            barrier = ReportBarrier(record, save, manifest["barrier_expected_rows"])
            barrier.acquire()
        record["stage"] = "fresh producer admission"
        producer = launch(packet, "producer", index)
        remember(producer)
        wait_ready(packet, manifest, producer)
        record["preparation_id"] = producer["ready"]["preparation_id"]
        first_child, second = (observer, producer) if index == 1 else (producer, observer)
        record["stage"] = "await actual first SQL request"
        signal(packet, manifest, first_child, "go")
        started = time.monotonic()
        for _ in range(512):
            rows = active(connection, children)
            record["samples"].append(dict(seconds=time.monotonic() - started, rows=rows))
            found = any(
                (
                    barrier.is_blocked_report(r, first_child["process"].pid)
                    if barrier is not None
                    else r["host_process_id"] == first_child["process"].pid
                    and (index == 1 or r["report_batch"])
                )
                for r in rows
            )
            if found:
                if barrier is not None:
                    barrier.facts["observed_blocking_clock"] = time.monotonic()
                record["first_request_observed"] = True
                break
            if first_child["process"].poll() is not None:
                break
            time.sleep(0.02)
        # Missing a short first request is not permission to repeat the report.
        # Complete the other already-owned independent reader/report once.
        signal(packet, manifest, second, "go")
        if barrier is not None:
            from report_barrier import release_when_reader_enters

            release_when_reader_enters(barrier, connection, children, record, started)
        record["stage"] = "sample actual report/reader overlap"
        for _ in range(512):
            rows = active(connection, children)
            record["samples"].append(dict(seconds=time.monotonic() - started, rows=rows))
            credit_rows = rows
            if barrier is not None:
                if not barrier.facts["released"]:
                    raise ValueError("Control-held work is not engine overlap evidence")
                credit_rows = [r for r in rows if r["blocking_session_id"] == 0]
            concurrent, executing = overlap(credit_rows, children)
            record["simultaneous_requests"] |= concurrent
            record["simultaneous_running_or_runnable"] |= executing
            if executing or any(c["process"].poll() is not None for c in children):
                break
            time.sleep(0.02)
        record["sampling_seconds"] = time.monotonic() - started
        record["stage"] = "await original report capture and reader completion"
        save()
    except BaseException as error:
        first = error
        record["first_failure"] = dict(stage=record["stage"], **sql_error_facts(error))
    finally:
        if barrier is not None:
            try:
                barrier.finish()
            except BaseException as error:
                first = first or error
                if record["first_failure"] is None:
                    record["first_failure"] = dict(
                        stage="controlled barrier cleanup", **sql_error_facts(error)
                    )
        settle(packet, manifest, children, record, save)
        for child, item in zip(children, record["children"], strict=True):
            item["exit_code"] = child["exit_code"]
            number = ({1: 2, 2: 5} if child["role"] == "producer" else {1: 3, 2: 6})[index]
            path = packet / f"stage-{number}.json"
            if path.exists():
                value = json.loads(path.read_bytes())
                item["outcome"] = value.get("outcome")
                item["first_failure"] = value.get("first_failure")
                item["physical_cleanup"] = value.get("physical_cleanup")
                if value.get("pid") != item["pid"]:
                    first = first or ValueError("Completed receipt belongs to another child")
            else:
                first = first or ValueError("Original child receipt unavailable")
        record["finished"] = datetime.now(UTC).isoformat()
        record["functional_passed"] = len(children) == 2 and all(
            c.get("outcome") == "passed"
            and c.get("exit_code") == 0
            and c.get("physical_cleanup", {}).get("all_closed_by_callers") is True
            for c in record["children"]
        )
        write_new(packet / f"stage-{4 if index==1 else 7}.json", record)
    if first is not None:
        raise first
    if record["cleanup_failures"] or not record["functional_passed"]:
        raise ValueError("Original report/capture or reader did not complete")
    return record
