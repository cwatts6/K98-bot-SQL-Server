"""Opt-in disposable SQL rehearsal; never accepts the production database name."""

import argparse
import json
from pathlib import Path
from uuid import uuid4

import pyodbc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--server", required=True)
    parser.add_argument("--database", required=True)
    args = parser.parse_args()
    if not args.database.startswith("K98_Aggregate_Disposable_"):
        raise ValueError("An explicitly named disposable database is required")
    # Values are ODBC braced, including escaped closing braces.
    quote = lambda value: "{" + value.replace("}", "}}") + "}"
    pyodbc.pooling = False
    conn = pyodbc.connect(
        "DRIVER={ODBC Driver 17 for SQL Server};SERVER=" + quote(args.server)
        + ";DATABASE=" + quote(args.database)
        + ";Trusted_Connection=yes;TrustServerCertificate=yes", autocommit=True
    )
    sql = (Path(__file__).resolve().parents[1] /
           "deploy/amendments/20261012_aggregate_row_permissions.sql").read_text()
    cur = conn.cursor()
    server, database = cur.execute(
        "SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME()"
    ).fetchone()
    if database != args.database or not database.startswith("K98_Aggregate_Disposable_"):
        raise ValueError("Connected database differs")
    principal = "AggregateAmendmentProbe_" + uuid4().hex
    cur.execute(f"CREATE USER [{principal}] WITHOUT LOGIN")
    sid = bytes(cur.execute("SELECT sid FROM sys.database_principals WHERE name=?", principal).fetchone()[0])
    cur.execute("CREATE TABLE #AggregatePermissionAmendment (ExpectedServer nvarchar(128),"
                "ExpectedDatabase nvarchar(128),PrincipalName nvarchar(128),LoginSid varbinary(85),Action varchar(8))")

    def apply(action="Apply", *, expected_server=server, expected_db=database,
              expected_user=principal, expected_sid=sid):
        cur.execute("DELETE #AggregatePermissionAmendment")
        cur.execute("INSERT #AggregatePermissionAmendment VALUES (?,?,?,?,?)",
                    expected_server, expected_db, expected_user, expected_sid, action)
        cur.execute(sql)
        while cur.nextset():
            pass

    def rights():
        return [(r[0], r[1], r[2]) for r in cur.execute(
            "SELECT OBJECT_NAME(major_id),permission_name,state FROM sys.database_permissions "
            "WHERE grantee_principal_id=USER_ID(?) AND class=1 ORDER BY 1,2", principal)]

    passed = []
    try:
        for label, kwargs in (
            ("wrong server", {"expected_server": "incorrect"}),
            ("wrong database", {"expected_db": "ROK_TRACKER"}),
            ("wrong SID", {"expected_sid": b"x" * 16}),
            ("wrong user", {"expected_user": "unrelated"}),
            ("wrong action", {"action": "invalid"}),
        ):
            try:
                apply(**kwargs)
            except pyodbc.Error:
                assert rights() == [], label
                passed.append(label)
            else:
                raise AssertionError(label)
        for right in ("GRANT SELECT", "DENY SELECT"):
            cur.execute(f"{right} ON OBJECT::KVK.SourceCampReportRow TO [{principal}]")
            baseline = rights()
            try:
                apply()
            except pyodbc.Error:
                assert rights() == baseline
                passed.append(right + " rejected")
            else:
                raise AssertionError(right)
            cur.execute(f"REVOKE SELECT ON OBJECT::KVK.SourceCampReportRow FROM [{principal}]")
        apply()
        expected = [(t, p, "G") for t in ("SourceCampReportRow", "SourceKingdomReportRow")
                    for p in ("INSERT", "SELECT")]
        assert rights() == expected
        apply()
        assert rights() == expected
        passed.extend(["exact four grants", "apply idempotent"])
        apply("Rollback")
        assert rights() == []
        apply("Rollback")
        assert rights() == []
        passed.extend(["exact rollback", "rollback idempotent"])
    finally:
        # Only the unique fixture identity created by this connection is removed.
        cur.execute(f"DROP USER [{principal}]")
        conn.close()
    print(json.dumps({"server": server, "database": database, "passed": passed}, indent=2))


if __name__ == "__main__":
    main()
