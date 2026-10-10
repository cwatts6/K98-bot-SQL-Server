# Transactional module release profile

The normal Bot updater can call `deploy/Deploy-SqlMigration.ps1` with an exact
profile path/hash, SQL commit, release UUID and explicit server/database. This
uses `deploy/SqlDeploy.ModuleRelease.ps1`. The historical arbitrary-SQL runner
remains separate and is not made automatically resumable by this profile.

Each reviewed profile is UTF-8 JSON with exactly these fields:

```json
{
  "version": 1,
  "profile": "module_grants_v1",
  "migration_id": "20261010_901_example",
  "database_collation": "Latin1_General_CI_AS",
  "tempdb_collation": "Latin1_General_CI_AS",
  "compatibility_level": 160,
  "modules": [{
    "schema": "dbo", "name": "Example", "type": "P",
    "before_sha256": "<SHA256 of exact existing UTF-16LE definition>",
    "file": "Example.sql", "sha256": "<SHA256 of exact UTF-8 file>"
  }],
  "grants": [{
    "schema": "dbo", "name": "Example", "principal": "ExampleReader",
    "permission": "EXECUTE", "before": "ABSENT"
  }],
  "requires": [{
    "migration_id": "20261010_900_predecessor",
    "sha256": "<exact existing migration checksum>", "status": "Applied"
  }]
}
```

The placeholders are deliberately invalid, not runnable migration inputs. Save a
real profile as `migrations/<migration_id>.release.json`, with module files beside
it. Review exact preimages independently; never replace expected hashes with
current observations to bypass a refusal. Required history must exist before the
release starts; it may explicitly preserve a known Failed predecessor.

Profile JSON is pinned to LF by `.gitattributes`. For every new byte-hashed module
file, add an explicit `migrations/<module_filename>.sql text eol=lf` attribute
before calculating its checksum; the repository's general SQL rule uses CRLF.
Hash the exact committed Git blob bytes and verify a fresh checkout reproduces
them. Do not change historical migration attributes or normalize bytes at runtime.
The Bot preparer reads exact blobs from the pinned SQL commit, so its packaged
bytes must agree with these reviewed hashes and any standalone runner checkout.

Modules must already exist, be unsigned P/V objects with ANSI_NULLS and
QUOTED_IDENTIFIER on, and use ordinary schema/object names. The file begins with
exact `CREATE OR ALTER PROCEDURE [schema].[name]` or VIEW and contains one driver
batch, with no GO/SQLCMD prelude, CLR or encryption. SQL Server stores this prefix
as `CREATE   PROCEDURE`/VIEW; the postimage is derived from the reviewed input
using that exact prefix conversion. The body and line endings are never normalized.
UTF-8 BOM is refused. Grants must be new explicit object EXECUTE/SELECT grants to
existing ordinary SQL/Windows users. The Bot preparer additionally refuses any
sealed startup object/principal or overlapping release stages.

Enabled database/server DDL triggers and ledger triggers are refused. The runner
requires visible metadata, the existing SchemaMigrationHistory and
DeploymentRunHistory tables, exact database/tempdb collations and compatibility,
a full backup within 24 hours, and a log backup within 30 minutes except SIMPLE
recovery. No backup, schema creation, data migration or external effect is performed.

An exclusive session application lock serializes this profile. Apply records an
attempt, then changes modules/grants and writes Applied plus Succeeded in the same
transaction. Rollback leaves the prior attempt, including Failed history, intact.
Status obtains the same lock: an exact Applied identity, its linked Succeeded
attempt with the same release UUID, and exact postimages prove committed;
absent Applied plus exact preimages and matching prior attempts proves
rollback. A live owner, mismatched history or drift is unresolved and never replayed.
The bounded history query refuses more than 256 attempts.

Operations: Preflight is read-only (exit 0 for compatible committed/unstarted/
rolled-back states); Status and Verify return 0 committed, 10 unstarted, 11 proven
rollback, 20 unresolved/refused. Apply verifies committed state without repeating
effects. No force, skip-backup or legacy override switches are accepted.

Run `deploy/Test-ModuleReleaseProfile.ps1` offline. The opt-in
`validation/rehearse_module_release.py` uses only the named local K98DEV instance,
creates a unique disposable database and backup, and retains its transcripts.
It never connects to MINI_AMD. It exercises actual Windows PowerShell 5.1,
SqlClient, differing tempdb collation, exact Unicode/LF metadata, retained rollback,
committed drift, live-owner exclusion and real process death before/after commit.
The process-death test wraps only the fixture library to pause at a fault point;
the outer Deploy-SqlMigration file remains byte-identical, and status/resume use
the uninstrumented production runner.
