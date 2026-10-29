"""Emit an inert profile for explicit observed bindings; never query or deploy SQL."""

import argparse
import json
import re


def profile(database_collation, tempdb_collation, compatibility_level, requires=()):
    if any(
        not isinstance(c, str) or not re.fullmatch(r"[A-Za-z0-9_]{1,128}", c)
        for c in (database_collation, tempdb_collation)
    ):
        raise ValueError("Exact observed collations required")
    if type(compatibility_level) is not int or compatibility_level not in (
        130,
        140,
        150,
        160,
    ):
        raise ValueError("Exact observed compatibility required")
    if not isinstance(requires, (tuple, list)) or len(requires) > 64:
        raise ValueError("Bounded predecessor history required")
    seen = set()
    for row in requires:
        if (
            not isinstance(row, dict)
            or set(row) != {"migration_id", "sha256", "status"}
            or not isinstance(row["migration_id"], str)
            or not re.fullmatch(r"[0-9]{8}_[0-9]{3}_[A-Za-z0-9_]+", row["migration_id"])
            or row["migration_id"] in seen
            or not isinstance(row["sha256"], str)
            or not re.fullmatch(r"[a-f0-9]{64}", row["sha256"])
            or row["status"] not in ("Applied", "Failed")
        ):
            raise ValueError("Exact unique predecessor history required")
        seen.add(row["migration_id"])
    return dict(
        version=1,
        profile="mge_finalisation_v1",
        migration_id="20261029_001_mge_board_finalisation",
        database_collation=database_collation,
        tempdb_collation=tempdb_collation,
        compatibility_level=compatibility_level,
        requires=list(requires),
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-collation", required=True)
    parser.add_argument("--tempdb-collation", required=True)
    parser.add_argument("--compatibility-level", required=True, type=int)
    parser.add_argument(
        "--requires-json",
        required=True,
        help="Explicit reviewed history array, including []",
    )
    args = parser.parse_args()
    print(
        json.dumps(
            profile(
                args.database_collation,
                args.tempdb_collation,
                args.compatibility_level,
                json.loads(args.requires_json),
            ),
            indent=2,
        )
    )
