"""Retained-fixture continuation guards; no SQL connection or writes."""

from copy import deepcopy
import json
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import continue_mge_finalisation as continuation
from test_mge_finalisation_harness import approval


def test_retained_evidence_hash_is_mandatory(tmp_path):
    p = tmp_path / "results.json"
    p.write_text(json.dumps({"target": continuation.DATABASE}))
    with pytest.raises(AssertionError, match="Retained evidence differs"):
        continuation.read_bound(p, continuation.PRIOR_RESULTS_SHA256)


@pytest.mark.parametrize(
    "change", ["valid", "target", "creation", "files", "child", "earlier", "n14", "n15"]
)
def test_continuation_only_accepts_exact_prior_failure(monkeypatch, tmp_path, change):
    monkeypatch.setattr(continuation, "RETAINED_EVIDENCE", tmp_path)
    old = approval()
    new = deepcopy(old)
    new["bot_commit"] = "c" * 40
    new["sql_commit"] = "d" * 40
    prior = dict(
        target=continuation.DATABASE,
        cases={
            f"N{i:02}": dict(
                status="PASS" if i < 14 else "FAIL" if i == 14 else "NOT_RUN"
            )
            for i in range(17)
        },
    )
    if change == "target":
        prior["target"] = "production"
    if change == "creation":
        new["create_date"] = "new"
    if change == "files":
        new["files"] = ["different"]
    if change == "child":
        new["allow_child_faults"] = True
    if change == "earlier":
        prior["cases"]["N12"]["status"] = "NOT_RUN"
    if change in ("n14", "n15"):
        prior["cases"][change.upper()]["status"] = "PASS"
    monkeypatch.setattr(
        continuation,
        "read_bound",
        lambda path, sha: prior if path.name == "results.json" else old,
    )
    if change == "valid":
        assert continuation.validate_prior(tmp_path, new) == (prior, old)
    else:
        with pytest.raises(AssertionError):
            continuation.validate_prior(tmp_path, new)


def test_copied_evidence_cannot_select_fresh_claim(monkeypatch, tmp_path):
    retained = tmp_path / "retained"
    copied = tmp_path / "copied"
    retained.mkdir()
    copied.mkdir()
    for directory in (retained, copied):
        (directory / "results.json").write_bytes(b"identical prior evidence")
    claim = retained / "continuation-claim.json"
    claim.write_bytes(b"original attempt retained")
    monkeypatch.setattr(continuation, "RETAINED_EVIDENCE", retained)
    monkeypatch.setattr(
        continuation,
        "read_bound",
        lambda *args: pytest.fail("Must refuse before reads"),
    )
    with pytest.raises(AssertionError, match="Canonical retained evidence"):
        continuation.validate_prior(copied, approval())
    assert claim.read_bytes() == b"original attempt retained"
    assert not (copied / "continuation-claim.json").exists()
