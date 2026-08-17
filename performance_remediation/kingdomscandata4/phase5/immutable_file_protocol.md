# Phase 5 immutable fallback-file protocol

Phase 5.0 replaces the reusable `downloads\stats.csv` work identity with one
unique completed filename carried through publication, SQL claim, digest,
bulk load, receipt and archive.

## Identity and directory contract

- Completed leaf name: `stats_<32 lowercase hexadecimal characters>.ready.csv`.
- Producer temporary file: a private, non-matching name in `Import_Ready`,
  such as `.stats_<token>.tmp`.
- Ready path:
  `C:\discord_file_downloader\downloads\Import_Ready\<completed-name>`.
- Claimed path:
  `C:\discord_file_downloader\downloads\Import_Claimed\<completed-name>`.
- Archive path:
  `C:\discord_file_downloader\downloads\Import_Archive\<completed-name>`.

The bot writes and closes the temporary file, flushes it, then atomically
renames it to the completed leaf in the same directory. It passes only that
leaf name to `dbo.UPDATE_ALL2 @CompletedFileName`.

SQL validates the fixed filename shape, atomically moves the ready file into
`Import_Claimed`, transfers file ownership to the xp_cmdshell identity, performs the final reset of
that exact file to the inherited Claimed-directory DACL, and verifies the resulting ACL,
then hashes the claimed path and records the ACL timestamp and owner with the claim. The bulk
load reads only the claimed path. SQL rehashes after `BULK INSERT`, commits the
receipt and claim together, moves the same claimed identity to its derived
archive path, and rehashes the destination before either status advances.

## ACL contract

- The bot runtime identity may create and rename files in `Import_Ready`.
- The bot runtime identity must not modify, replace, delete or create files in
  `Import_Claimed`.
- The SQL Server/xp_cmdshell execution identity may read and move completed
  files from `Import_Ready`, and exclusively read, move and delete files in
  `Import_Claimed`.
- The SQL execution identity may create archive entries in `Import_Archive`.
- Interactive users, unrelated services and scheduled tasks must not have
  mutation rights in `Import_Claimed`.
- The three directories must be on the same local NTFS volume so both
  ready-to-claimed and claimed-to-archive operations are same-volume renames.
- `Import_Ready` must grant the SQL/xp_cmdshell identity Full Control on inherited
  files so SQL can change the DACL and owner after moving one completed identity.
- `Import_Claimed` and `Import_Archive` use protected allow-list DACLs. The bot
  receives Read/Execute at most; broad `Users`, `Authenticated Users`, and
  `Everyone` mutation grants are absent.
- Because a same-volume move retains the source security descriptor, every fresh
  or recovered claimed file is ownership-transferred before its final DACL reset and
  the first digest. Directory ACLs alone are not sufficient; the former bot owner
  must lose owner-level DACL control before the final inherited policy is applied.

The combined-release preflight must retain the effective `icacls` output for
all three directories and a probe proving the bot cannot mutate a claimed
file while SQL can hash and move it.

## Recovery rules

- `claiming` plus ready present: retry the ready-to-claimed move.
- `claiming`/`failed` plus claimed present: resume from the claimed file.
- `claimed`: verify the stored digest and retry the SQL import.
- `imported`: reconcile the archive move without allocating another scan.
- `duplicate`: archive the duplicate identity without allocating another scan.
- source absent/archive present: rehash the archive and advance once.
- both source and archive present, neither present, or any digest mismatch:
  fail closed for operator reconciliation.

Never republish a different file under an existing completed name. A corrected
retry always receives a new 32-hex token and therefore a new immutable identity.

