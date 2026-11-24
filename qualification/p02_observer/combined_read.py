"""One read-only combined-dispatch proof under the actual verifier budget owner."""

from collections import Counter
from dataclasses import asdict
import json
import time

from scripts.verify_k98_running_release import ObservationConnections
from services.export_execution_protocol import encode
from services.export_schema_fingerprint import application_metadata_fingerprint


def _read_once(connect, observe, write_json, *, complete, **options):
    timings = []
    owner = ObservationConnections(lambda: connect(application=True))
    started = time.perf_counter()
    first_failure = None
    try:
        with owner:
            owner.observation_phase("application")
            observed = observe(owner(), timings=timings, **options)
    except BaseException as error:
        first_failure = error
        raise
    finally:
        for name, value in (
            ("catalogue-timings.json", timings),
            ("combined-budget.json", owner.evidence()),
        ):
            try:
                write_json(name, value)
            except BaseException as error:
                if first_failure is None:
                    raise
                first_failure.add_note("Evidence save also failed: " + type(error).__name__)
    elapsed = time.perf_counter() - started
    write_json(
        "combined-observation.json",
        dict(boundary=asdict(observed.boundary), value=observed.value, complete=complete),
    )
    assert owner.first_failure is None
    assert len(owner.connections) == 1 and all(c.closed for c in owner.connections)
    return observed, timings, owner, elapsed


def _same_boundary(observed, baseline):
    previous = baseline["boundary"]
    current = json.loads(json.dumps(asdict(observed.boundary), default=str))
    assert current["generation"] == previous["generation"] == 270
    assert current["identity"][:5] + current["identity"][9:] == (
        previous["identity"][:5] + previous["identity"][9:]
    )
    assert current["identity"][6:9] == previous["identity"][6:9]
    return current


def prove_combined_read(*, connect, observe, baseline, write_json, check, receipt):
    def read():
        observed, timings, owner, elapsed = _read_once(
            connect,
            observe,
            write_json,
            complete=True,
            observation_batches=True,
            combined_boundaries=True,
        )

        def normalize(value):
            return json.loads(json.dumps(value, default=str))

        current = _same_boundary(observed, baseline)
        expected, actual = baseline["value"], normalize(observed.value)
        assert set(actual) == set(expected)
        for section in ("metadata", "schema_identity"):
            assert set(actual[section]) == set(expected[section])
            for category in expected[section]:
                assert Counter(map(encode, actual[section][category])) == Counter(
                    map(encode, expected[section][category])
                ), (section, category)
        for key in set(expected) - {"metadata", "schema_identity"}:
            assert actual[key] == expected[key], key
        fingerprint = application_metadata_fingerprint(
            actual["metadata"], actual["schema_identity"]
        )
        assert fingerprint == "26b0b4894bcf18cbcb4d8736fef0cf89ac9936205553efdc93601d49b0cc48bd"
        assert len(timings) == 133
        assert sum(row["embedded_boundary"] for row in timings) == 131
        assert sum(row["boundary"] for row in timings) == 2
        assert owner.statements == 134  # Includes its connection-setup dispatch.
        assert owner.first_failure is None
        assert len(owner.connections) == 1 and all(c.closed for c in owner.connections)
        facts = dict(
            generation=current["generation"],
            fingerprint=fingerprint,
            all_rows_permissions_lifecycle_equal=True,
            ordinary_queries=131,
            boundary_tokens=133,
            collector_odbc_dispatches=133,
            owner_dispatches_including_setup=134,
            maximum_combined_batch_seconds=max(r["native_seconds"] for r in timings),
            observation_seconds=elapsed,
            cleanup="acknowledged",
            whole_three_contract_caller_acceptance=False,
        )
        write_json("catalogue-cost-result.json", facts)
        assert elapsed <= 15 and facts["maximum_combined_batch_seconds"] <= 0.250, facts
        return facts

    check("complete-combined-read-parity-and-owner-cost", read)
    assert receipt["business_operations"] == receipt["production_operations"] == 0


def prove_combined_categories(*, connect, observe, baseline, write_json, check, receipt):
    def read():
        observed, timings, owner, elapsed = _read_once(
            connect,
            observe,
            write_json,
            complete=False,
            combined_only=True,
        )
        _same_boundary(observed, baseline)
        expected = {
            "metadata.indexes": baseline["value"]["metadata"]["indexes"],
            "identity.default_constraints": baseline["value"]["schema_identity"][
                "default_constraints"
            ],
        }
        assert set(observed.value) == set(expected)
        for category, rows in expected.items():
            assert Counter(map(encode, observed.value[category])) == Counter(
                map(encode, rows)
            ), category
        assert len(timings) == 14 and owner.statements == 15
        assert sum(row["embedded_boundary"] for row in timings) == 12
        assert sum(row["boundary"] for row in timings) == 2
        facts = dict(
            generation=270,
            rows_equal={key: len(rows) for key, rows in expected.items()},
            ordinary_queries=12,
            boundary_tokens=14,
            collector_odbc_dispatches=14,
            owner_dispatches_including_setup=15,
            maximum_combined_batch_seconds=max(r["native_seconds"] for r in timings),
            observation_seconds=elapsed,
            cleanup="acknowledged",
            full_collector_repeated=False,
            business_dispatches=0,
        )
        write_json("catalogue-cost-result.json", facts)
        assert elapsed <= 15 and facts["maximum_combined_batch_seconds"] <= 0.250, facts
        return facts

    check("remaining-index-and-default-batches", read)
    assert receipt["business_operations"] == receipt["production_operations"] == 0
