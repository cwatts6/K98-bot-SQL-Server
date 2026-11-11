"""D4 child-admission source pins; preserve every historical D3 pin and body.

D4c also assigns stable names to the four not-yet-installed ledger constraints.
Offline candidate custody only: not a release profile or installed acceptance.
The CI entrypoint uses only the Python standard library.
"""

import hashlib
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PREDECESSOR = "0ebe0d3fe099ec62c76333c8b58c9049d93dcece"
HISTORICAL_CHECKER_SHA256 = (
    "e050f95323fdd1a713afd155be7b0c578d8b46e02e325a1eb2350a7adfd884ac"
)
CHANGED = {
    "sql_schema/dbo.usp_MaintenanceImport.StoredProcedure.sql": "a76c698bd55f7f9713ea4d6743f770891bd7056486d313ec7b0e25ccec3cf191",
    "sql_schema/dbo.usp_MaintenanceConfiguration.StoredProcedure.sql": "15ee1b792793900642b03dc78ff921de943cef9dc0f8b29db9dda5d8a8a9d907",
    "sql_schema/dbo.usp_MaintenancePlayerReport.StoredProcedure.sql": "410bc525b35632e00a07e95aef9c4bd009ced64c5d7c78bbcfd2ae976fdad9df",
    "sql_schema/dbo.usp_MaintenanceKvkOutput.StoredProcedure.sql": "1fd581ce7c7066120d755ccbb68ab7b74659e27d3005e376622ccbc554ec68b4",
    "sql_schema/dbo.usp_MaintenanceFinalStats.StoredProcedure.sql": "1c3bff775200de3741968c1106987f78cc4bc22793d183a6e541c566ca22dea6",
    "sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql": "178b424c41eecdc8576f877d84eac90c9e8bda8e5c43c39fcc99906ceeb9210c",
    "sql_schema/dbo.MaintenanceWork.Table.sql": "ec50b60e036e37fa6d544fdc238c98110ecd90cc4eeaba62f8a87905d1f215fa",
    "sql_schema/dbo.MaintenanceConfigurationWork.Table.sql": "daf873d3bb536af31da3ca280d0c30407c2408250a79779a5ac0fd04d7ce0eea",
    "sql_schema/dbo.MaintenanceBackupWork.Table.sql": "8da1f75c0ff37655956703f2556c03732b1649d9b71ee52622197dacffdcd63c",
    "sql_schema/dbo.MaintenanceKvkWork.Table.sql": "5aef0c3e01bd0aa3d609447e4aae981d4a9d76ca0accaee7918cb7b1a98c37c2",
}


def digest(raw):
    return hashlib.sha256(
        raw.decode("utf-8-sig").replace("\r\n", "\n").encode()
    ).hexdigest()


def verify(files, expected):
    if set(files) != set(expected):
        raise ValueError("Incomplete or foreign D4 source inventory")
    for path, value in files.items():
        if digest(value) != expected[path]:
            raise ValueError("Unreviewed D4 source: " + path)


def test_historical_and_current_source_custody():
    checker = (ROOT / "deploy/Test-P02D3MaintenanceSource.ps1").read_bytes()
    assert digest(checker) == HISTORICAL_CHECKER_SHA256
    old = dict(
        re.findall(
            r"'(sql_schema/[^']+)'='([a-f0-9]{64})'", checker.decode("utf-8-sig")
        )
    )
    assert len(old) == 23 and len(CHANGED) == 10 and set(CHANGED) <= set(old)
    historical = {
        path: subprocess.check_output(
            ["git", "-C", str(ROOT), "show", PREDECESSOR + ":" + path], timeout=10
        )
        for path in old
    }
    verify(historical, old)
    expected = dict(old, **CHANGED)
    current = {path: (ROOT / path).read_bytes() for path in expected}
    verify(current, expected)
    # Both Windows checkout and repository line endings authenticate identically.
    verify(
        {
            p: raw.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            for p, raw in current.items()
        },
        expected,
    )
    for path in expected:
        tampered = dict(current)
        tampered[path] += b"\n-- unreviewed fixture mutation\n"
        try:
            verify(tampered, expected)
        except ValueError:
            pass
        else:
            raise AssertionError("Source mutation admitted: " + path)
    for path in expected:
        incomplete = dict(current)
        del incomplete[path]
        try:
            verify(incomplete, expected)
        except ValueError:
            pass
        else:
            raise AssertionError("Missing source admitted: " + path)
    print(
        "PASS: 23 historical and current pins, ten exact successors, LF/CRLF, mutations and missing members"
    )


if __name__ == "__main__":
    test_historical_and_current_source_custody()
