# SQL-authenticated immutable import file visibility

The real production `S11_ExportApplication` SQL login returned zero from
`master.dbo.xp_fileexist` for the existing immutable ready file, while the same
login returned one from `sys.dm_os_file_exists`. A Windows-authenticated SSMS
session, including `EXECUTE AS LOGIN`, returned one from the old primitive.
Impersonation therefore did not reproduce the real authentication boundary.

Migration `20261008_001_sql_auth_import_file_visibility` replaces all eleven
existence checks in CLAIM_KS4_IMPORT_FILE (six), IMPORT_STAGING_PROC_CORE (one)
and ARCHIVE_IMPORT_STAGING_FILE (four). Scalar COALESCE defaults absent/null
results to zero and reads only file_exists, never directory existence. The
fixed paths, validated immutable basename, move/hash/ACL checks, locking,
claim state transitions and transaction boundaries are preserved. It grants
no permissions and changes no execution context. UPDATE_RALLY_DATA is outside
this demonstrated immutable scan import lifecycle and is unchanged.

## Deployment

1. Review and merge this SQL PR. Use the SQL promotion guide's backup and
   explicit migration-selection workflow; do not redeploy historical schema
   snapshots or rerun a permission migration to accommodate these new bodies.
2. Disable the automatic launch task and gracefully drain the existing Bot,
   watchdog and authority. Confirm the execution session closed and native
   processes stopped. Preserve the failed preparation and immutable CSV.
3. Apply only the new migration. It requires ROK_TRACKER, SQL Server 2022 or
   newer, no caller transaction, closed execution sessions, a schema lock,
   exact before/after module hashes, caller execution, the reviewed SET options
   and no signatures. Any mismatch aborts and rolls back all module changes.
   The migration is idempotent only for its exact installed postimages.
4. Re-read and independently accept the actual application SQL contract,
   including the changed definitions and system-function dependency. Install
   a fresh protected automatic startup seed. The old accepted contract must
   not be reused. Existing permission manifests describe historical installation
   profiles; these behavior-changing definitions are not whitespace variants.
5. Reconcile the exact retained preparation/claim using pinned evidence and a
   separately reviewed recovery plan. This migration releases nothing and
   does not replay the import. Preserve the ready CSV and prove its digest
   and absence of a committed receipt before any approved resumption.
6. Start through the verified automatic task, resume the approved import once,
   then verify committed import, archived identity and complete provider export.
   Keep KVK intake/recovery closed until that acceptance is complete.

The positive native-function probe establishes file visibility with existing
rights. It does not establish that subsequent shell moves, bulk import,
archive or provider publication succeed. Those remain production acceptance
checks. Rollback is an independently reviewed forward fix, not a blind return
to the demonstrated false-negative primitive.

## Validation

Run `deploy/Test-SqlAuthImportFileVisibility.ps1` for exact embedded/source
postimages and an inverse proof that all eleven replacements are the entire
procedure-body delta. The PR also records local SQL fixture validation and
the real production login's read-only visibility probe. No production import
or export is executed by these source checks.

Historical signed/direct permission-profile tests also run the new exact
forward-migration validator, then reconstruct and verify the original three
source files against their unchanged historical pins. This validates both
reviewed generations without allowing the new definitions to be signed or
installed by an old permission migration. Refreshing the live runtime contract
after the forward migration remains mandatory.
