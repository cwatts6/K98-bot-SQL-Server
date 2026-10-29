"""Native exercises. Called only after rehearse_mge_finalisation's write guard.

Assertions use fresh SQL reads. Discord is always a fake. Test-owned connection
adapters are distinct from production connection/retry policy qualification.
"""

import asyncio
from concurrent.futures import ThreadPoolExecutor
from contextlib import closing
from datetime import UTC, datetime
import importlib
import json
from pathlib import Path
import subprocess
import sys
from threading import Barrier
import time
from types import SimpleNamespace
from unittest.mock import AsyncMock
import uuid


def require(value, message):
    if not value:
        raise AssertionError(message)


def rejected(action, code):
    try:
        action()
    except Exception as exc:
        require(str(code) in str(exc), "Unexpected rejection: " + str(exc))
        return str(exc)
    raise AssertionError("Expected SQL rejection " + str(code))


def run_cases(run):
    install_faults = []

    def install():
        run.runner("Preflight")
        run.runner("Status", 10)
        require(
            run.approval["allow_child_faults"],
            "Install interruption needs explicit child fault approval",
        )
        from rehearse_mge_finalisation import PS, digest

        for boundary in range(1, 5):
            process = subprocess.Popen(
                [
                    PS,
                    "-NoProfile",
                    "-NonInteractive",
                    "-File",
                    str(Path(__file__).with_name("Invoke-MgeInstallFaultChild.ps1")),
                    "-ProfilePath",
                    str(run.profile_path),
                    "-ProfileSHA256",
                    digest(run.profile_path.read_bytes()),
                    "-ExpectedCommit",
                    run.approval["sql_commit"],
                    "-ReleaseId",
                    run.release,
                    "-ExpectedLogin",
                    run.approval["login"],
                    "-Boundary",
                    str(boundary),
                ],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                with ThreadPoolExecutor(max_workers=1) as executor:
                    acknowledgement = executor.submit(process.stdout.readline)
                    try:
                        require(
                            acknowledgement.result(timeout=60).strip()
                            == "BOUNDARY:" + str(boundary),
                            "SQL child boundary not reached",
                        )
                    finally:
                        if process.poll() is None:
                            process.kill()
                        process.wait(timeout=10)
                run.runner("Status", 11)
                require(
                    not run.query(
                        "SELECT name FROM sys.tables WHERE name='MGE_BoardFinalisation'"
                    ),
                    "Interrupted DDL persisted",
                )
                require(
                    not run.query("SELECT * FROM dbo.SchemaMigrationHistory"),
                    "Interrupted Applied receipt persisted",
                )
                install_faults.append(
                    dict(boundary=boundary, owned_pid=process.pid, status="rolled_back")
                )
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=10)
                (run.output / f"install-child-{boundary}.stderr.txt").write_text(
                    process.stderr.read(), encoding="utf-8"
                )
                for pipe in (process.stdin, process.stdout, process.stderr):
                    pipe.close()
        run.runner("Apply")
        before = run.query("SELECT * FROM dbo.SchemaMigrationHistory")
        run.runner("Apply")
        run.runner("Verify")
        require(
            before == run.query("SELECT * FROM dbo.SchemaMigrationHistory"),
            "Repeat altered receipt",
        )
        return dict(
            driver="System.Data.SqlClient / Windows PowerShell 5.1",
            receipt=before,
            go_splitting="None: five explicit driver batches, each CREATE TRIGGER alone",
        )

    run.record(
        "N00",
        lambda: dict(
            identity=run.query(
                "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server, DB_NAME() AS [database]"
            )[0],
            guards="Approval digest, opt-in, login, fresh database, creation timestamp, files and source pair passed before fixtures",
        ),
    )
    run.record("N01", install)
    dal = run.load_dal()
    completion, final = dal["completion"], dal["finalisation"]
    now = lambda: datetime.now(UTC)
    complete = lambda event: completion.mark_event_completed(event, 9001, now())
    state = lambda event: run.query(
        "SELECT Status FROM dbo.MGE_Events WHERE EventId=?", event
    )[0]["Status"]

    def drift():
        # Each drift is inside an owned transaction and rolled back. Verification
        # on that same connection invokes the real installed profile postimage code.
        script = Path(__file__).with_name("Test-MgeFinalisationImages.ps1")
        result = subprocess.run(
            [
                r"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(script),
                "-ProfilePath",
                str(run.profile_path),
                "-ExpectedLogin",
                run.approval["login"],
            ],
            capture_output=True,
            timeout=120,
        )
        (run.output / "N02-images.stdout.txt").write_bytes(result.stdout)
        (run.output / "N02-images.stderr.txt").write_bytes(result.stderr)
        require(
            result.returncode == 0, "Native image fault cases failed; see transcript"
        )
        run.runner("Verify")
        return dict(
            postimage_faults="Missing index, disabled/altered trigger and added column each refused; rollback verified",
            install_interruptions=install_faults,
        )

    run.record("N02", drift)

    def signup(event, governor=1001):
        return dal["signup"].insert_signup(
            event_id=event,
            governor_id=governor,
            governor_name_snapshot="Synthetic",
            discord_user_id=9001,
            request_priority="High",
            preferred_rank_band=None,
            requested_commander_id=run.commander,
            requested_commander_name="Qualification",
            current_heads=0,
            kingdom_role=None,
            gear_text=None,
            armament_text=None,
            source="discord",
            now_utc=now(),
        )

    def award(event, signup_id, governor=1001):
        return dal["roster"].insert_award(
            event_id=event,
            signup_id=signup_id,
            governor_id=governor,
            governor_name_snapshot="Synthetic",
            requested_commander_id=run.commander,
            requested_commander_name="Qualification",
            awarded_rank=1,
            award_status="awarded",
            waitlist_order=None,
            internal_notes=None,
            assigned_by_discord_id=9001,
            now_utc=now(),
        )

    active = run.event()

    def writers():
        signup_id = signup(active)
        require(
            isinstance(signup_id, int) and signup_id > 0, "Signup OUTPUT INTO result"
        )
        award_id = award(active, signup_id)
        require(isinstance(award_id, int) and award_id > 0, "Award OUTPUT INTO result")
        ok = dal["rules"].update_event_rules_text_with_audit(
            event_id=active,
            actor_discord_id=9001,
            action_type="qualification",
            old_rule_mode="fixed",
            new_rule_mode="fixed",
            old_rules_text=None,
            new_rules_text="Synthetic rules",
            now_utc=now(),
        )
        require(ok, "Rules OUTPUT INTO result")
        require(
            len(run.query("SELECT * FROM dbo.MGE_RuleAudit WHERE EventId=?", active))
            == 1,
            "Rules audit missing",
        )
        return dict(event=active, signup_id=signup_id, award_id=award_id)

    run.record("N03", writers)

    def completion_case():
        require(complete(active), "First completion")
        targets = final.targets(active)
        require(
            len(targets) == 3 and len({str(t["FinalisationId"]) for t in targets}) == 1,
            "Atomic inventory",
        )
        require(not complete(active), "Second completion must be inert")
        require(final.targets(active) == targets, "Second completion changed inventory")
        require(state(active) == "completed", "Domain freeze not committed")
        return dict(event=active, targets=targets)

    run.record("N04", completion_case)

    def sparse():
        observed = []
        for count in (0, 1, 2):
            event = run.event(count)
            require(complete(event), "Sparse target completion")
            require(len(final.targets(event)) == count, "Invented target")
            observed.append(dict(event=event, count=count))
        event = run.event(0)
        run.execute(
            "UPDATE dbo.MGE_Events SET SignupEmbedChannelId=101 WHERE EventId=?", event
        )
        require(
            not complete(event)
            and state(event) == "signup_open"
            and not final.targets(event),
            "Partial identity committed",
        )
        for status in ("created", "completed"):
            event = run.event(0, status)
            require(
                not complete(event) and not final.targets(event),
                "Invalid/legacy completion changed state",
            )
        return dict(
            targets=observed, partial_identity="refused", legacy_completed="no backfill"
        )

    run.record("N05", sparse)

    def child_loss(phase):
        require(
            run.approval["allow_child_faults"],
            "Named fixture-child termination needs explicit approval",
        )
        event = run.event()
        process = subprocess.Popen(
            [
                sys.executable,
                str(Path(__file__).with_name("mge_finalisation_child.py")),
                "--approval",
                str(run.output / "approval.json"),
                "--bot-root",
                str(run.bot_root),
                "--event",
                str(event),
                "--phase",
                phase,
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            # Bounded acknowledgement wait, not a sleep used as evidence.
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(process.stdout.readline)
                try:
                    acknowledgement = future.result(timeout=30).strip()
                except BaseException:
                    process.kill()
                    process.wait(timeout=10)
                    raise
            require(
                acknowledgement == phase,
                "Fixture child did not reach requested boundary",
            )
            process.kill()  # Only the handle returned by this Popen is terminated.
            process.wait(timeout=10)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            stderr = process.stderr.read()
            (run.output / (phase + ".stderr.txt")).write_text(stderr, encoding="utf-8")
            for pipe in (process.stdin, process.stdout, process.stderr):
                pipe.close()
        expected = "completed" if phase == "committed" else "signup_open"
        require(state(event) == expected, "Independent domain outcome differs")
        require(
            len(final.targets(event)) == (3 if phase == "committed" else 0),
            "Independent inventory outcome differs",
        )
        return dict(
            event=event,
            child_pid=process.pid,
            acknowledged=phase,
            durable_state=expected,
            replay=False,
        )

    def inventory_failure_and_loss():
        event = run.event(1)
        run.execute(
            "INSERT dbo.MGE_BoardFinalisation(EventId,BoardKind,FinalisationId,PublishVersion,ChannelId,MessageId,DeliveryState) VALUES(?,'signup',NEWID(),0,101,201,'pending')",
            event,
        )
        before = final.targets(event)
        rejection = rejected(lambda: complete(event), 2627)
        require(
            state(event) == "signup_open" and final.targets(event) == before,
            "Inventory failure partially committed completion",
        )
        return dict(
            insertion_failure=dict(event=event, error=rejection, preserved=before),
            client_loss=child_loss("uncommitted"),
        )

    run.record("N06", inventory_failure_and_loss)
    run.record("N07", lambda: child_loss("committed"))

    def frozen():
        before = final.targets(active)
        errors = []
        for sql in (
            "UPDATE dbo.MGE_Events SET RulesText=N'stale' WHERE EventId=?",
            "UPDATE dbo.MGE_Signups SET CurrentHeads=CurrentHeads+1 WHERE EventId=?",
            "DELETE dbo.MGE_Awards WHERE EventId=?",
            "UPDATE dbo.MGE_Awards SET InternalNotes=N'stale' WHERE EventId=?",
        ):
            errors.append(rejected(lambda: run.execute(sql, active), 51830))
        # An awarded signup is protected first by its award FK (547), which
        # cannot qualify the AFTER DELETE trigger. Use a separate unreferenced
        # signup so the expected 51830 proves the freeze guard itself executed.
        delete_event = run.event(1)
        delete_signup = signup(delete_event, 4002)
        require(isinstance(delete_signup, int), "Unreferenced delete fixture missing")
        complete(delete_event)
        errors.append(
            rejected(
                lambda: run.execute(
                    "DELETE dbo.MGE_Signups WHERE SignupId=?", delete_signup
                ),
                51830,
            )
        )
        require(
            bool(
                run.query(
                    "SELECT SignupId FROM dbo.MGE_Signups WHERE SignupId=?",
                    delete_signup,
                )
            ),
            "Rejected signup delete changed state",
        )
        other = run.event()
        other_signup = signup(other, 1002)
        errors.append(
            rejected(
                lambda: run.execute(
                    "UPDATE dbo.MGE_Signups SET EventId=? WHERE SignupId=?",
                    active,
                    other_signup,
                ),
                51830,
            )
        )
        errors.append(
            rejected(
                lambda: run.execute(
                    "UPDATE dbo.MGE_Signups SET EventId=? WHERE EventId=?",
                    other,
                    active,
                ),
                51830,
            )
        )
        empty_completed = run.event(0, "completed")
        errors.append(
            rejected(
                lambda: run.execute(
                    "DELETE dbo.MGE_Events WHERE EventId=?", empty_completed
                ),
                51830,
            )
        )
        # Event INSERT is intentionally legal: only existing completed rows freeze.
        with closing(run.connection()) as connection:

            def direct_signup():
                return dal["signup"].insert_signup(
                    event_id=active,
                    governor_id=4001,
                    governor_name_snapshot="Synthetic",
                    discord_user_id=9001,
                    request_priority="High",
                    preferred_rank_band=None,
                    requested_commander_id=run.commander,
                    requested_commander_name="Qualification",
                    current_heads=0,
                    kingdom_role=None,
                    gear_text=None,
                    armament_text=None,
                    source="discord",
                    now_utc=now(),
                    cursor=connection.cursor(),
                )

            errors.append(rejected(direct_signup, 51830))
            connection.rollback()
        # A second active signup has no existing award key, so the rejection must
        # come from the target event freeze rather than uniqueness/FK enforcement.
        errors.append(
            rejected(
                lambda: run.execute(
                    dal["roster"].SQL_INSERT_AWARD,
                    active,
                    other_signup,
                    1002,
                    "Synthetic",
                    run.commander,
                    "Qualification",
                    2,
                    None,
                    "awarded",
                    None,
                    0,
                    None,
                    9001,
                    now().replace(tzinfo=None),
                    now().replace(tzinfo=None),
                ),
                51830,
            )
        )
        other_award = award(other, other_signup, 1002)
        errors.append(
            rejected(
                lambda: run.execute(
                    "UPDATE dbo.MGE_Awards SET EventId=? WHERE AwardId=?",
                    active,
                    other_award,
                ),
                51830,
            )
        )
        errors.append(
            rejected(
                lambda: run.execute(
                    "UPDATE dbo.MGE_Awards SET EventId=? WHERE EventId=?", other, active
                ),
                51830,
            )
        )
        snapshots = run.query(
            "SELECT EventId,RulesText FROM dbo.MGE_Events WHERE EventId IN (?,?) ORDER BY EventId",
            active,
            other,
        )
        errors.append(
            rejected(
                lambda: run.execute(
                    "UPDATE dbo.MGE_Events SET RulesText=N'mixed' WHERE EventId IN (?,?)",
                    active,
                    other,
                ),
                51830,
            )
        )
        require(
            snapshots
            == run.query(
                "SELECT EventId,RulesText FROM dbo.MGE_Events WHERE EventId IN (?,?) ORDER BY EventId",
                active,
                other,
            ),
            "Mixed partial commit",
        )
        require(
            final.targets(active) == before, "Freeze rejection changed target inventory"
        )
        return dict(
            errors=errors,
            snapshots=snapshots,
            event_insert="New completed fixture allowed; no update/delete allowed",
        )

    run.record("N08", frozen)

    def ordering():
        observations = []
        # The first transaction holds the real event update lock. A second worker
        # enters only after that lock is acquired; DMV evidence proves it blocked.
        for completion_first in (False, True):
            event = run.event()
            with closing(run.connection()) as first:
                first.execute(
                    "SELECT EventId FROM dbo.MGE_Events WITH (UPDLOCK,HOLDLOCK) WHERE EventId=?",
                    event,
                ).fetchall()
                spid = first.execute("SELECT @@SPID").fetchval()
                if completion_first:
                    first.execute(
                        "UPDATE dbo.MGE_Events SET Status='completed' WHERE EventId=?",
                        event,
                    )
                else:
                    first.execute(
                        "UPDATE dbo.MGE_Events SET RulesText=N'writer first' WHERE EventId=?",
                        event,
                    )
                entered = Barrier(2)

                def second():
                    entered.wait(timeout=10)
                    return (
                        signup(event, 2000 + event)
                        if completion_first
                        else complete(event)
                    )

                with ThreadPoolExecutor(max_workers=1) as executor:
                    future = executor.submit(second)
                    entered.wait(timeout=10)
                    deadline = time.monotonic() + 8
                    blocked = []
                    while time.monotonic() < deadline and not future.done():
                        blocked = run.query(
                            "SELECT session_id,blocking_session_id,wait_type FROM sys.dm_exec_requests WHERE blocking_session_id=?",
                            spid,
                        )
                        if blocked:
                            break
                        time.sleep(0.05)
                    if not blocked:
                        first.rollback()
                        raise AssertionError("No native blocking evidence")
                    first.commit()
                    outcome = future.result(timeout=15)
                require(state(event) == "completed", "Race lost domain freeze")
                if completion_first:
                    require(
                        outcome is None
                        and not run.query(
                            "SELECT SignupId FROM dbo.MGE_Signups WHERE EventId=?",
                            event,
                        ),
                        "Late writer committed",
                    )
                else:
                    require(outcome is True, "Completion did not follow writer")
                observations.append(
                    dict(
                        event=event,
                        completion_first=completion_first,
                        blocked=blocked,
                        outcome=outcome,
                    )
                )
        return dict(schedules=observations, deadlock_retry=False)

    run.record("N09", ordering)

    def cas():
        target = final.targets(active)[0]
        require(
            isinstance(target["Revision"], bytes), "pyodbc rowversion must be bytes"
        )
        for field, value in (
            ("EventId", -1),
            ("BoardKind", "awards" if target["BoardKind"] != "awards" else "signup"),
            ("FinalisationId", str(uuid.uuid4())),
            ("Revision", b"\x00" * 8),
            ("PublishVersion", 999),
            ("ChannelId", 999),
            ("MessageId", 999),
        ):
            stale = dict(target)
            stale[field] = value
            require(not final.transition(stale, "failed"), "Stale CAS won: " + field)
        require(
            final.transition(target, "failed", payload='{"title":"retained"}'),
            "Valid CAS refused",
        )
        updated = next(
            t for t in final.targets(active) if t["BoardKind"] == target["BoardKind"]
        )
        require(updated["Revision"] != target["Revision"], "Rowversion unchanged")
        require(not final.transition(target, "held"), "Old revision changed row")
        return dict(before=target, after=updated)

    run.record("N10", cas)

    def terminal():
        event = run.event(1)
        complete(event)
        target = final.targets(event)[0]
        require(
            final.transition(target, "failed", payload='{"title":"first"}'),
            "Payload capture",
        )
        target = final.targets(event)[0]
        require(
            final.transition(target, "confirmed", payload='{"title":"replacement"}'),
            "Confirm",
        )
        target = final.targets(event)[0]
        require(
            target["PayloadJson"] == '{"title":"first"}', "Immutable payload replaced"
        )
        require(not final.transition(target, "held"), "Terminal changed")
        retired_event = run.event(1)
        complete(retired_event)
        t = final.targets(retired_event)[0]
        for actor in (None, 0, -1, "9001"):
            try:
                final.transition(t, "retired", actor_id=actor)
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid retirement actor accepted")
        require(final.transition(t, "retired", actor_id=9001), "Retirement failed")
        require(
            not final.transition(final.targets(retired_event)[0], "pending"),
            "Retirement reopened",
        )
        return dict(confirmed=event, retired=retired_event, payload_retained=True)

    run.record("N11", terminal)

    def settling():
        event = run.event(1)
        complete(event)
        snapshot = final.targets(event)[0]
        barrier = Barrier(2)

        def change(state):
            barrier.wait(timeout=10)
            return final.transition(
                snapshot, state, actor_id=9001 if state == "retired" else None
            )

        with ThreadPoolExecutor(max_workers=2) as executor:
            a, b = executor.submit(change, "confirmed"), executor.submit(
                change, "retired"
            )
            outcomes = [a.result(timeout=20), b.result(timeout=20)]
        require(sum(outcomes) == 1, "CAS race did not have exactly one winner")
        return dict(event=event, outcomes=outcomes, final=final.targets(event))

    run.record("N12", settling)

    def delivery():
        import discord

        adapter = importlib.import_module("mge.mge_finalisation")

        async def exercise():
            results = []
            for mode in ("lost_ack", "mismatch", "missing", "forbidden"):
                event = run.event(1)
                complete(event)
                payload = {"title": "Retained final", "type": "rich"}
                final.transition(
                    final.targets(event)[0], "unknown", payload=json.dumps(payload)
                )
                # Module reload and a new SQL read represent loss of in-memory state.
                importlib.reload(adapter)
                message = SimpleNamespace(
                    embeds=[discord.Embed.from_dict(payload)],
                    components=[],
                    edit=AsyncMock(),
                )
                channel = SimpleNamespace(fetch_message=AsyncMock(return_value=message))
                if mode == "mismatch":
                    message.embeds = [discord.Embed(title="Other")]
                if mode in ("missing", "forbidden"):
                    error = discord.NotFound if mode == "missing" else discord.Forbidden
                    channel.fetch_message.side_effect = error(
                        SimpleNamespace(
                            status=404 if mode == "missing" else 403, reason="fixture"
                        ),
                        "fixture",
                    )
                bot = SimpleNamespace(
                    get_channel=lambda _: channel, fetch_channel=AsyncMock()
                )
                context = dict(
                    EventId=event,
                    Status="completed",
                    PublishVersion=0,
                    SignupEmbedChannelId=101,
                    SignupEmbedMessageId=201,
                )
                await adapter.deliver_target(bot, context, final.targets(event)[0])
                target = final.targets(event)[0]
                require(
                    target["DeliveryState"]
                    == ("confirmed" if mode == "lost_ack" else "held"),
                    "Readback state",
                )
                await adapter.deliver_target(bot, context, target)
                require(
                    channel.fetch_message.await_count == 1
                    and message.edit.await_count == 0,
                    "Readback replay/network on terminal",
                )
                results.append(dict(mode=mode, event=event, target=target))
            return dict(
                readbacks=results,
                restart="module reload plus fresh SQL connection; no real Discord",
            )

        return asyncio.run(exercise())

    run.record("N13", delivery)

    def results_import():
        result = dal["results"]
        batch = result.create_import_batch(
            active, "controlled", "upload", "synthetic.csv", "a" * 64, 9001
        )
        count = result.replace_event_results(
            batch,
            active,
            "controlled",
            [dict(rank=1, player_id=1001, player_name="Synthetic", score=100)],
        )
        require(
            count == 1 and result.is_event_completed(active),
            "Completed result workflow blocked",
        )
        return dict(
            event=active,
            import_id=batch,
            rows=run.query(
                "SELECT * FROM dbo.MGE_FinalResults WHERE EventId=?", active
            ),
        )

    run.record("N14", results_import)

    def multistep():
        event = run.event()
        sid = signup(event, 3001)
        aid = award(event, sid, 3001)
        complete(event)
        error = rejected(
            lambda: run.execute("DELETE dbo.MGE_Awards WHERE AwardId=?", aid), 51830
        )
        require(
            bool(run.query("SELECT AwardId FROM dbo.MGE_Awards WHERE AwardId=?", aid)),
            "Earlier committed award lost",
        )
        return dict(
            event=event,
            calls=[
                "signup committed",
                "award committed",
                "completion committed",
                "later delete rolled back",
            ],
            rejection=error,
            whole_operation_atomic=False,
        )

    run.record("N15", multistep)

    def inventory():
        for _ in range(55):
            complete(run.event(1))
        expected = [
            r["EventId"]
            for r in run.query(
                "SELECT DISTINCT EventId FROM dbo.MGE_BoardFinalisation WHERE DeliveryState IN ('pending','failed','unknown') ORDER BY EventId"
            )
        ]
        seen, cursor, calls = [], 0, 0
        started = time.perf_counter()
        while True:
            page = final.pending_events(cursor)
            calls += 1
            seen.extend(r["EventId"] for r in page)
            if len(page) < 50:
                break
            cursor = page[-1]["EventId"]
        require(seen == expected and len(seen) > 50, "Keyset inventory loss/duplicates")
        count_start = time.perf_counter()
        counts = final.counts()
        events = final.event_counts()
        return dict(
            events=len(seen),
            page_calls=calls,
            traversal_seconds=count_start - started,
            counts_seconds=time.perf_counter() - count_start,
            counts=counts,
            event_counts=events,
            indexes=run.query(
                "SELECT i.name,u.user_seeks,u.user_scans FROM sys.indexes i LEFT JOIN sys.dm_db_index_usage_stats u ON u.object_id=i.object_id AND u.index_id=i.index_id AND u.database_id=DB_ID() WHERE i.object_id=OBJECT_ID('dbo.MGE_BoardFinalisation')"
            ),
        )

    run.record("N16", inventory)
