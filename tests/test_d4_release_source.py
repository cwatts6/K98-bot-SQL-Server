"""Offline custody of the complete D4 payload and current authoritative sources."""

import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ID = "20261111_001_p02_d4_combined"


def test_fixed_release_source_custody():
    profile_raw = (ROOT / f"migrations/{ID}.release.json").read_bytes()
    assert (
        hashlib.sha256(profile_raw).hexdigest()
        == "57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171"
    )
    profile = json.loads(profile_raw)
    raw = (ROOT / f"migrations/{ID}.sql").read_bytes()
    assert hashlib.sha256(raw).hexdigest() == profile["script"]["sha256"]
    text = raw.decode("utf-8")
    tables = {
        "MaintenanceWork",
        "MaintenanceConfigurationWork",
        "MaintenanceBackupWork",
        "MaintenanceKvkWork",
    }
    names = [i["name"].removeprefix("dbo.") for i in profile["images"]]
    assert len(names) == len(set(names)) == 30
    order = sorted(
        names,
        key=lambda n: (
            0 if n in tables else 1 if n == "usp_P02LegacyQueueState" else 2,
            n,
        ),
    )
    parts = []
    for name in order:
        kind = "Table" if name in tables else "StoredProcedure"
        source = (ROOT / f"sql_schema/dbo.{name}.{kind}.sql").read_text(
            encoding="utf-8-sig"
        )
        if kind == "Table":
            body = "\n".join(
                b.strip() for b in re.split(r"(?im)^GO\s*$", source) if b.strip()
            )
        else:
            start = re.search(r"(?im)^(?:ALTER|CREATE OR ALTER) PROCEDURE", source)
            assert start, name
            batches = [
                b.strip()
                for b in re.split(r"(?im)^GO\s*$", source[start.start() :])
                if b.strip()
            ]
            assert len(batches) == 1, name
            body = re.sub(
                r"\A(?:ALTER|CREATE OR ALTER) PROCEDURE",
                "CREATE OR ALTER PROCEDURE",
                batches[0],
            )
        parts.extend(
            [
                "-- dbo." + name,
                "EXEC sys.sp_executesql N'" + body.replace("'", "''") + "';",
            ]
        )
    parts.append(
        "IF @@TRANCOUNT<>1 OR XACT_STATE()<>1 THROW 52981,'D4 release transaction escaped.',1;"
    )
    assert text[text.index("-- dbo.") :] == "\n".join(parts) + "\n"
    phase1 = json.loads(
        (
            ROOT / "migrations/20261109_001_p02_phase1_sql_exports.release.json"
        ).read_bytes()
    )
    assert profile["requires"][:-1] == phase1["requires"]
    assert profile["requires"][-1] == dict(
        migration_id=phase1["migration_id"],
        sha256="520b58c1b25d80bd28f32324d99b5fede0d6191ddab93ac93469ed5c1f6e4041",
        status="Applied",
    )


if __name__ == "__main__":
    test_fixed_release_source_custody()
    print(
        "PASS: fixed complete D4 payload equals all 30 authoritative sources; historical Phase 1 requirements retained."
    )
