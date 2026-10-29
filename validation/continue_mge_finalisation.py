"""One bounded N14-N16 continuation of the retained 29 October fixture.

No install, backup, restore, cleanup, DDL, child termination or SQL replay.
Original evidence and its applied release identity remain unchanged. A durable
claim prevents blind retry after any interruption, including before SQL writes.
"""

import argparse
from contextlib import closing
import json
from pathlib import Path

from mge_finalisation_cases import require, run_remaining_cases
from rehearse_mge_finalisation import (
    DATABASE,
    ROOT,
    NativeRun,
    digest,
    guard_identity,
    validate_approval,
    verify_checkout,
)

PRIOR_RESULTS_SHA256 = (
    "b845a34c915426984e5682c54cbf2a32e235da7267674742219ee2d3c7046f6b"
)
PRIOR_APPROVAL_SHA256 = (
    "e046af6d2759db3ffab1e5f1e1da84c02faf25305d27597d176eec8a7f65ae26"
)
PRIOR_PROFILE_SHA256 = (
    "752efb070f9302c88d49fa093273efb24a7e4e3aa63b70f54065fe94f5075bcb"
)
RETAINED_EVIDENCE = Path(
    r"C:\discord_file_downloader\.codex_artifacts\mge-finalisation-native-run-20261029"
)


def read_bound(path, expected):
    raw = path.read_bytes()
    require(
        len(raw) <= 2_000_000 and digest(raw) == expected, "Retained evidence differs"
    )
    return json.loads(raw)


def validate_prior(previous, approval):
    # A copied pre-attempt report must not select a fresh durable claim location.
    require(
        previous.resolve() == RETAINED_EVIDENCE.resolve(),
        "Canonical retained evidence directory required",
    )
    prior = read_bound(previous / "results.json", PRIOR_RESULTS_SHA256)
    old = read_bound(previous / "approval.json", PRIOR_APPROVAL_SHA256)
    require(prior["target"] == DATABASE, "Retained target differs")
    for key, value in old.items():
        if key not in ("bot_commit", "sql_commit", "allow_child_faults"):
            require(approval[key] == value, "Continuation changed approved " + key)
    require(approval["allow_child_faults"] is False, "Continuation has no child faults")
    require(
        all(prior["cases"][f"N{i:02}"]["status"] == "PASS" for i in range(14)),
        "Earlier cases incomplete",
    )
    require(
        prior["cases"]["N14"]["status"] == "FAIL",
        "Only the known failed N14 may continue",
    )
    require(
        all(prior["cases"][case]["status"] == "NOT_RUN" for case in ("N15", "N16")),
        "Remaining cases already attempted",
    )
    return prior, old


def guard_retained(run, previous, prior, old):
    with closing(run.connection()) as connection:
        guard_identity(connection, run.approval)
        connection.rollback()
    # Verify the original committed release. Never relabel its GitCommit or adopt
    # its receipt into a new release just because qualification source changed.
    profile_path = previous / "20261029_001_mge_board_finalisation.release.json"
    read_bound(profile_path, PRIOR_PROFILE_SHA256)
    verifier = NativeRun(old, run.bot_root, run.output)
    verifier.release, verifier.profile_path = prior["release"], profile_path
    verifier.runner("Verify")
    run.operations.extend(verifier.operations)
    receipt = run.query("SELECT * FROM dbo.SchemaMigrationHistory")
    require(
        json.loads(json.dumps(receipt, default=str))
        == prior["cases"]["N01"]["evidence"]["receipt"],
        "Original migration receipt changed",
    )
    require(
        not run.query("SELECT ImportId FROM dbo.MGE_ResultImports"),
        "Results import outcome exists; inspect, do not replay",
    )
    require(
        not run.query("SELECT FinalResultId FROM dbo.MGE_FinalResults"),
        "Results already persisted; do not replay",
    )
    events = run.query(
        "SELECT EventId,VariantId,Status FROM dbo.MGE_Events ORDER BY EventId"
    )
    require(
        [e["EventId"] for e in events] == sorted(prior["event_ids"]),
        "Retained event inventory changed",
    )
    active = prior["cases"]["N04"]["evidence"]["event"]
    event = next(e for e in events if e["EventId"] == active)
    require(event["Status"] == "completed", "Retained event is not completed")
    variants = run.query("SELECT VariantId,VariantName FROM dbo.MGE_Variants")
    commanders = run.query("SELECT CommanderId,CommanderName FROM dbo.MGE_Commanders")
    require(
        variants == [dict(VariantId=event["VariantId"], VariantName="Qualification")],
        "Fixture variant differs",
    )
    require(
        len(commanders) == 1 and commanders[0]["CommanderName"] == "Qualification",
        "Fixture commander differs",
    )
    run.variant, run.commander = event["VariantId"], commanders[0]["CommanderId"]
    return active


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approval", required=True)
    parser.add_argument("--approval-sha256", required=True)
    parser.add_argument("--bot-root", required=True)
    parser.add_argument("--previous", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    raw = Path(args.approval).read_bytes()
    require(len(raw) <= 65536, "Approval exceeds bound")
    approval = json.loads(raw)
    validate_approval(approval, args.approval_sha256, raw)
    previous, output, bot_root = (
        Path(p).resolve() for p in (args.previous, args.output, args.bot_root)
    )
    prior, old = validate_prior(previous, approval)
    sources = dict(
        sql=verify_checkout(ROOT, approval["sql_commit"]),
        bot=verify_checkout(bot_root, approval["bot_commit"]),
    )
    output.mkdir(parents=True, exist_ok=False)
    (output / "approval.json").write_bytes(raw)
    (output / "sources.json").write_text(
        json.dumps(sources, indent=2), encoding="utf-8"
    )
    run = NativeRun(approval, bot_root, output)
    run.results = {case: dict(status="NOT_RUN") for case in ("N14", "N15", "N16")}
    run.save()
    # Claim before observing/writing; retain even on failure. No age expiry or
    # force flag. validate_prior binds this to one canonical evidence directory;
    # copied evidence cannot select a different claim even when its bytes match.
    with (previous / "continuation-claim.json").open("x", encoding="utf-8") as claim:
        json.dump(
            dict(
                output=str(output),
                approval_sha256=args.approval_sha256,
                prior_results_sha256=PRIOR_RESULTS_SHA256,
            ),
            claim,
        )
    with closing(run.connection()) as owner:
        lock = owner.execute(
            "DECLARE @r int; EXEC @r=sys.sp_getapplock @Resource=N'K98.MGE.Qualification.Continuation', @LockMode='Exclusive', @LockOwner='Session', @LockTimeout=0; SELECT @r;"
        ).fetchone()[0]
        require(lock >= 0, "Another continuation owns the retained fixture")
        owner.rollback()
        active = guard_retained(run, previous, prior, old)
        (output / "predecessor.json").write_text(
            json.dumps(
                dict(
                    previous=str(previous),
                    results_sha256=PRIOR_RESULTS_SHA256,
                    original_release=prior["release"],
                    original_sql_commit=old["sql_commit"],
                    carried_cases=list(prior["cases"])[:14],
                ),
                indent=2,
            ),
            encoding="utf-8",
        )
        run_remaining_cases(run, active)
    run.save()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
