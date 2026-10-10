# Outcome installation across catalog collations

`20261010_001_stats_import_outcomes_collation` replaces the original October 9
installer. The original file and its ledger history remain unchanged. Normal
migration selection now refuses the original installer and names the replacement.

The original comparison mixed database catalog metadata with `tempdb` catalog
metadata in EXCEPT expressions. On MINI_AMD these use `Latin1_General_CI_AS` and
`SQL_Latin1_General_CP1_CI_AS`. The replacement compares metadata text under
`Latin1_General_100_BIN2`; it does not alter stored column collations or weaken
object checks. Its procedure definitions and grants are unchanged. Any existing
original receipt must have the reviewed checksum and an Applied or Failed status;
the replacement does not update that receipt.

The deployment adapter must first reconcile the failed attempt and verify the
unchanged drained predecessor. Do not invoke this migration directly to repair a
stopped release. The bot contract and release amendment must be reviewed together.

## Validation

`validation/test_stats_outcome_collation.py` creates a new synthetic local fixture
only when explicitly invoked with `--execute`. It refuses an existing fixture,
checks the exact K98DEV server identity, chooses a database collation different
from tempdb, reproduces the old failure, observes rollback after closing the
connection, installs the replacement, verifies approved module definitions and
repeat metadata checks, and retains the database READ_ONLY. It never calls an
import procedure, connects to production or touches older rehearsal databases.

The October 10 fixture `K98_S11_Collation_20261010_r3` passed with database
`Latin1_General_CI_AS` and tempdb `SQL_Latin1_General_CP1_CI_AS`. The original Failed
receipt was unchanged and the receipt table remained empty. Final retention was
completed by a nonpooled connection after the initial retention attempt refused
pooled fixture connections. Earlier authoring-test fixtures remain READ_ONLY.

This proves installation and metadata comparison behavior, not the complete
production import workload. Runtime tests separately require an exact Applied
replacement receipt and the independently approved predecessor lineage.
