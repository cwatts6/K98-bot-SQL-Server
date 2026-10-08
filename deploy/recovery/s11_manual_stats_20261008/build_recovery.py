"""Build the single operator script from reviewed sources; no network/SQL access."""
import hashlib
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
SCHEMA = ROOT.parents[2] / "sql_schema"


def module_hash(name):
    source = (SCHEMA / ("dbo." + name + ".StoredProcedure.sql")).read_text(encoding="utf-8-sig")
    matches = list(re.finditer(r"(?im)^(?:CREATE OR ALTER|ALTER) PROCEDURE", source))
    body = source[matches[-1].start():]
    body = re.sub(r"(?im)^GO\s*$", "", body)
    body = body[body.upper().index("PROCEDURE"):].strip()
    return hashlib.sha256(body.encode("utf-16le")).hexdigest()


def build():
    template = (ROOT / "Recover-S11Stats.template.ps1").read_text(encoding="utf-8")
    return (template.replace("@@SQL@@", (ROOT / "settle.sql").read_text(encoding="utf-8").rstrip())
        .replace("@@STATS_HASH@@", module_hash("SP_Stats_for_Upload"))
        .replace("@@LOCK_HASH@@", module_hash("ACQUIRE_KS4_IMPORT_LOCK")))


if __name__ == "__main__":
    output = Path(sys.argv[1])
    with output.open("x", encoding="utf-8-sig", newline="\r\n") as stream:
        stream.write(build())
    print(str(output.resolve()))
    print("SHA256:", hashlib.sha256(output.read_bytes()).hexdigest())
