"""Offline tests: no SQL connection, database writes, or child termination."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_mge_finalisation_profile import profile
import rehearse_mge_finalisation as harness


def approval():
    return dict(
        version=1,
        server=harness.IDENTITY,
        database=harness.DATABASE,
        login="Fixture\\Operator",
        create_date="2026-10-29T00:00:00",
        files=[r"C:\fixture\a.mdf", r"C:\fixture\a.ldf"],
        backup_path="C:\\fixture\\" + harness.DATABASE + "_qualification.bak",
        bot_commit="a" * 40,
        sql_commit="b" * 40,
        database_collation="Latin1_General_CI_AS",
        tempdb_collation="SQL_Latin1_General_CP1_CI_AS",
        compatibility_level=160,
        allow_fixture_writes=True,
        allow_child_faults=False,
    )


@pytest.mark.parametrize(
    "field,value",
    [
        ("server", "MINI_AMD"),
        ("database", "ROK_TRACKER"),
        ("allow_fixture_writes", False),
        ("allow_child_faults", 1),
        ("bot_commit", "main"),
        ("login", None),
        ("files", []),
        ("compatibility_level", True),
        ("version", True),
        ("backup_path", r"C:\unrelated.bak"),
    ],
)
def test_approval_refuses_before_connect(field, value):
    p = approval()
    p[field] = value
    raw = json.dumps(p).encode()
    sha = hashlib.sha256(raw).hexdigest()
    with patch.dict(
        os.environ,
        {
            "K98_MGE_APPROVED_TARGET": harness.IDENTITY
            + "|"
            + harness.DATABASE
            + "|"
            + sha
        },
    ):
        with pytest.raises(ValueError):
            harness.validate_approval(p, sha, raw)


def test_missing_opt_in_and_hash_mismatch_refuse():
    p = approval()
    raw = json.dumps(p).encode()
    sha = hashlib.sha256(raw).hexdigest()
    with patch.dict(os.environ, {}, clear=True):
        with pytest.raises(ValueError):
            harness.validate_approval(p, sha, raw)
    with patch.dict(
        os.environ,
        {
            "K98_MGE_APPROVED_TARGET": harness.IDENTITY
            + "|"
            + harness.DATABASE
            + "|"
            + sha
        },
    ):
        harness.validate_approval(p, sha, raw)
        with pytest.raises(ValueError):
            harness.validate_approval(p, "c" * 64, raw)


def test_default_discovery_queries_are_select_only():
    queries = []

    class Connection:
        def close(self):
            pass

        def rollback(self):
            pass

    def query(connection, sql, *args):
        queries.append(sql)
        if "ORIGINAL_LOGIN" in sql:
            return [dict(server=harness.IDENTITY, database="master", login="fixture")]
        if "ProductVersion" in sql:
            return [dict(data_path=None, log_path=None, backup_path=None)]
        return []

    with patch.object(harness, "connect", lambda database: Connection()), patch.object(
        harness, "rows", query
    ):
        result = harness.discover()
    assert result["database_writes"] is False
    assert all(sql.startswith("SELECT ") for sql in queries)
    assert len(queries) == 4


def test_dal_imports_use_only_explicit_test_adapters(tmp_path):
    bot = os.environ.get("K98_MGE_TEST_BOT_ROOT")
    if not bot:
        pytest.skip(
            "Explicit local Bot checkout needed for cross-repository import check"
        )
    script = """import sys
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from rehearse_mge_finalisation import NativeRun
run=NativeRun({},Path(sys.argv[2]),Path(sys.argv[3]))
run.connection=lambda: (_ for _ in ()).throw(AssertionError('SQL must not connect'))
assert len(run.load_dal())==6
import mge.mge_finalisation
print('six real DAL modules and final-delivery adapter imported without connecting')
"""
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            script,
            str(Path(harness.__file__).parent),
            bot,
            str(tmp_path),
        ],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stdout + result.stderr


def test_profile_author_requires_explicit_environment():
    assert (
        profile("Latin1_General_CI_AS", "SQL_Latin1_General_CP1_CI_AS", 160)["requires"]
        == []
    )
    with pytest.raises(ValueError):
        profile("unsafe; SQL", "SQL_Latin1_General_CP1_CI_AS", 160)
    with pytest.raises(ValueError):
        profile("Latin1_General_CI_AS", "SQL_Latin1_General_CP1_CI_AS", True)
