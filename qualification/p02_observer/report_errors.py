"""Allowlisted SQL wrapper facts; never persist free-form driver diagnostic text."""

import re

STAGES = frozenset(
    {
        "preflight",
        "import-lock",
        "publication-lock",
        "eligibility-snapshot",
        "header-preflight",
        "scan-date",
        "source-shape",
        "candidate-build",
        "header-recheck",
        "target-replacement",
        "maintenance-registration",
    }
)
_PATTERN = re.compile(
    r"SP_Stats_for_Upload: failed at stage=([a-z-]{1,64}), "
    r"KVK=(?:NULL|[0-9]{1,10}), expected scan=(?:NULL|[0-9]{1,10}), "
    r"proven scan=(?:NULL|[0-9]{1,10}), header revision=(?:NULL|[0-9]{1,10}), "
    r"source rows=[0-9]{1,19}, published rows=[0-9]{1,19}, SQL error=([0-9]{1,10}), detail="
)


def report_error_text(text):
    if not isinstance(text, str) or len(text) > 32768:
        return {}
    match = _PATTERN.search(text)
    if not match or match[1] not in STAGES or not 1 <= int(match[2]) <= 2147483647:
        return {}
    return {"report_stage": match[1], "inner_sql_error": int(match[2])}


def report_error_facts(error):
    args = getattr(error, "args", ())
    if not args or args[0] != "42000":
        return {}
    return report_error_text(" ".join(a[:8192] for a in args[1:5] if isinstance(a, str)))
