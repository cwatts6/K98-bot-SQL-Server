# Exact S11 postimage repair

The Windows SqlClient fallback reconstructed each input line using AppendLine,
turning the reviewed LF migration's procedure literals into CRLF. The migration's
normalized body guards passed, but the unchanged R4 application/legacy metadata
contracts correctly require the exact reviewed LF postimages. The production
read-only hashes match the independently reconstructed CRLF forms exactly.

Split-K98SqlBatches now preserves source terminators, including mixed input and
multiline literal text. Unicode decoding and standalone GO handling remain.
The offline file-route regression covers LF, CRLF, mixed, Unicode and invalid
bytes; the source proof independently reconstructs all four finite hashes from
immutable migration 20261010_002. Previous migration files remain unchanged.

Migration 20261010_003_stats_import_outcome_postimages requires the exact
Failed/Failed/Applied lineage, closed execution sessions, no outcome work,
unchanged unsigned module settings and either the exact LF or CRLF bodies.
It removes only the loader-added CR characters from those two known definitions.
Both guards run before alterations, the body is checked again before use,
and both exact raw postimages, identities, ownership and permissions are verified
inside one transaction. Unknown text, active work and signed modules are refused.
No business procedure runs; no old receipt, grant, sealed expectation or release
manifest is changed. Repeated direct verification makes no further alteration.

Use the reviewed companion operator launcher to verify the existing R4 drain and
stage before applying this one new migration through Deploy-SqlMigration.ps1.
Then the unchanged R4 contract verifier and launcher continue the same release.
Do not create another release amendment or replay an earlier migration.

The explicit local rehearsal creates a fresh K98DEV database, reproduces the
exact R4 two-object mismatch, exercises drift/active-session refusal and rollback,
and compares actual repaired metadata with the unchanged R4 comparison function.
Its --outer mode also exercises Git, backups and the real ledger runner, then
verifies a second run applies zero migrations. It retains every fixture read-only.
This is synthetic local SQL coverage, not proof of production Bot startup.
