"""Build the fixed one-file withdrawal from the reviewed operator wrapper."""
import hashlib
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent


def build():
    template = (ROOT.parent / "s11_manual_stats_20261008" / "Recover-S11Stats.template.ps1").read_text(encoding="utf-8")
    template = "\n".join(line for line in template.splitlines() if "@StatsHash" not in line and "@ImportLockHash" not in line)
    template = template.replace("@@SQL@@", (ROOT / "withdraw.sql").read_text(encoding="utf-8").rstrip())
    template = template.replace("50a5b6e5-d1d0-49dc-bf04-ab566047e152", "7c137998-16a2-4e4a-9906-10566ed2b3e6")
    template = template.replace("S11-manual-stats-result-", "S11-withdraw405-result-")
    template = template.replace("S11_ManualStats_Supersession", "S11_Withdraw_Unclaimed405")
    template = template.replace("COMMITTED_MANUAL_SUPERSESSION", "WITHDRAWN_UNCLAIMED_PREPARATION")
    template = template.replace("ALREADY_COMMITTED_NO_REPLAY", "ALREADY_WITHDRAWN_NO_CHANGE")
    template = template.replace("Derived SQL stats refreshed and historical hold superseded.", "Exact unclaimed ticket405 withdrawn; no stats rebuild performed.")
    template = template.replace("Return the JSON and next scheduled stats-refresh log for functional acceptance.", "Return this JSON, then run /kvk_admin refresh_stats_cache once and return its reply/log.")
    return template + "\n"


if __name__ == "__main__":
    output = Path(sys.argv[1])
    with output.open("x", encoding="utf-8-sig", newline="\r\n") as stream:
        stream.write(build())
    print(output.resolve())
    print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())
