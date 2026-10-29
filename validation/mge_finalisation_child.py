"""Owned fixture process for two explicit completion-loss boundaries, never a bot."""

import argparse
from contextlib import closing
from datetime import UTC, datetime
import hashlib
import importlib
import json
from pathlib import Path
import sys
import types

from rehearse_mge_finalisation import (
    DATABASE,
    connect,
    identity,
    validate_approval,
    verify_checkout,
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approval", required=True)
    parser.add_argument("--bot-root", required=True)
    parser.add_argument("--event", required=True, type=int)
    parser.add_argument("--phase", required=True, choices=("uncommitted", "committed"))
    args = parser.parse_args()
    raw = Path(args.approval).read_bytes()
    approval = json.loads(raw)
    validate_approval(approval, hashlib.sha256(raw).hexdigest(), raw)
    if not approval["allow_child_faults"] or args.event <= 0:
        raise ValueError("Explicit named fixture-child fault approval required")
    root = Path(args.bot_root).resolve()
    verify_checkout(root, approval["bot_commit"])
    sys.path.insert(0, str(root))
    db = types.ModuleType("stats_alerts.db")
    db.run_query = lambda *args, **kwargs: (_ for _ in ()).throw(
        AssertionError("Unexpected read adapter")
    )
    with closing(connect(DATABASE)) as connection:
        if identity(connection) != {
            k: approval[k] for k in ("server", "database", "login")
        }:
            raise ValueError("Child target identity differs")
        connection.rollback()
        connection.execute("SET XACT_ABORT ON; SET LOCK_TIMEOUT 5000; SET NOCOUNT OFF;")
        connection.commit()

        class BoundaryCursor:
            def __init__(self):
                self.cursor = connection.cursor()

            def execute(self, sql, *params):
                self.cursor.execute(sql, *params)
                if args.phase == "uncommitted" and "UPDATE dbo.MGE_Events" in sql:
                    print("uncommitted", flush=True)
                    sys.stdin.readline()  # Parent owns and terminates this exact process.
                    raise RuntimeError("Fault boundary released without termination")
                return self

            @property
            def rowcount(self):
                return self.cursor.rowcount

        def execute(callback):
            result = callback(BoundaryCursor())
            if not result:
                raise AssertionError("Fixture completion failed")
            connection.commit()
            print("committed", flush=True)
            sys.stdin.readline()
            raise RuntimeError("Fault boundary released without termination")

        db.exec_with_cursor = execute
        sys.modules["stats_alerts.db"] = db
        package = types.ModuleType("mge.dal")
        package.__path__ = [str(root / "mge/dal")]
        sys.modules["mge.dal"] = package
        completion = importlib.import_module("mge.dal.mge_completion_dal")
        completion.mark_event_completed(args.event, 9001, datetime.now(UTC))


if __name__ == "__main__":
    main()
