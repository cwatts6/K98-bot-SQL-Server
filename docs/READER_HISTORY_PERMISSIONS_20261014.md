# Reader activation: existing-account permission amendment

Entry point: `deploy/amendments/20261014_reader_history_permissions.sql`
This is a manually reviewed configuration release, not a schema migration.
The installed 20261013_001 history schema is a prerequisite. Do not reinstall it.

Exact additional direct rights:
  KVK.SourceExportHistory: SELECT, INSERT; UPDATE only AttemptCount and ContentHash.
  KVK.SourceExportHistoryRow: SELECT, INSERT.
No DELETE, row UPDATE, role, ownership, grant option or schema permission is added.
The first-capture transaction inserts the header and facts then sets the header
count/hash. SELECT/INSERT alone is insufficient. Subsequent capture verifies and
returns the same history snapshot; it does not incorporate later imports.

The caller must create #ReaderHistoryPermissionAmendment with columns
ExpectedServer nvarchar(128), ExpectedDatabase nvarchar(128),
PrincipalName nvarchar(128), LoginSid varbinary(85), Action varchar(8),
and insert exactly one independently reviewed identity on the same connection.
Action is Apply or Rollback. The batch has no production defaults.
Production permits only ROK_TRACKER / S11_ExportApplication, with exact login SID.
The separately approved local target is K98_ReaderActivation_Disposable_20261014.
Unexpected/partial grants, DENY or grant options stop execution. Apply and Rollback
are repeat-safe for the exact six-grant postimage and zero-grant baseline.

Before execution, drain the application/authority and validate the full previous
application and legacy permission contracts. Independently derive/review the new
effective-permission postimages. The six catalog grants are not the entire list of
effective permissions. Pin the SQL script checksum and final SQL/Bot commits in
the protected release packet. Apply grants and install the matching grant-plan,
whole-application/legacy permission hashes and reader registration together.
Use the generic reviewed configuration-release runner, not a source-only update.

After applying, compare actual full observations to the approved postimages as
the application identity, then require normal startup readiness. Never reseal
unexpected observations. No production execution is authorized by this document.

Rollback only while drained and only when retained release evidence proves the
six grants were absent before Apply. Restore source and protected contracts as a
coordinated set. Preserve business data, publications, attempts and history rows.
Do not clear uncertain export claims or replay provider writes to force progress.
