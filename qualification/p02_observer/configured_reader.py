"""Real application profile plus complete native three-contract comparison."""

import json
import os
from pathlib import Path


def run(packet, manifest, receipt):
    from independent_readers import sha
    import three_contracts as control

    from core.export_sql_connection import setup_custody_snapshot
    from kvk.dal.new_source_admin_dal import configured_connection

    receipt["transport"] = "actual configured_connection(application); unchanged TLS validation"
    try:
        credential = manifest["credential"]
        if credential["path"] != control.CREDENTIAL_PATH:
            raise ValueError("Exact guest-only credential required")
        raw = Path(credential["path"]).read_bytes()
        if sha(raw) != credential["sha256"]:
            raise ValueError("Original guest credential identity changed")
        password = control.unprotect(raw)
        os.environ.update(
            SQL_SERVER="MINI_AMD",
            SQL_DATABASE="ROK_TRACKER",
            S11_SQL_USERNAME=control.PRINCIPAL,
            S11_SQL_PASSWORD=password,
        )
        password = None
        candidate = json.loads((packet / "candidate-contracts.json").read_bytes())

        def connect():
            return configured_connection(sql_profile="application")

        actual = control.run_contracts(connect, candidate, manifest["release"], receipt)
        from independent_readers import encode, write_new

        if sha(encode(actual["application"])) != manifest["retained_application_value_sha256"]:
            raise ValueError("Complete configured-profile application rows differ")
        if sha(encode(actual["installation"])) != manifest["retained_fixed_value_sha256"]:
            raise ValueError("Complete configured-profile fixed rows differ")
        write_new(packet / "stage-4.json", actual)
        receipt["complete_parity_passed"] = True
        receipt["outcome"] = "passed"
    except BaseException:
        receipt["outcome"] = "failed"
        raise
    finally:
        password = None
        os.environ.pop("S11_SQL_PASSWORD", None)
        receipt["credential_environment_cleared"] = "S11_SQL_PASSWORD" not in os.environ
        receipt["setup_custody"] = setup_custody_snapshot()


def refusal_facts(error):
    """Classify transport refusal without emitting driver/credential prose."""
    from scripts.verify_k98_running_release import sql_error_facts

    facts = []
    seen = set()
    while error is not None and id(error) not in seen and len(facts) < 6:
        seen.add(id(error))
        text = str(error).lower()
        row = sql_error_facts(error)
        row["certificate_related"] = "certificate" in text or "ssl provider" in text
        row["untrusted_certificate_chain"] = "not trusted" in text and "certificate" in text
        facts.append(row)
        error = error.__cause__ or error.__context__
    return facts
