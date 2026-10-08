# S11 manual stats supersession — 8 October 2026

The operator approved a fresh derived-stats baseline while retaining the historical
SQL outcome as unknown. This one-time recovery is bound to the observed c983 hold,
aab3 waiter, successor SQL session and MINI_AMD operator. It does not infer rollback
from missing metadata, run UPDATE_ALL2, replay imports/provider work, change flags,
restart the bot, or install application source.

The worker acquires existing coordination and legacy producer locks, validates
exact state/fences and reviewed procedure definitions, executes the existing
SP_Stats_for_Upload, validates its result, records an audit in GenerationJson,
marks the two old preparations unavailable and clears the snapshot resource in
one transaction. The historical owner/fence on c983 remains recorded; aab3's fence
increments to invalidate its old lease. No permanent procedure or permission is
added. The source procedure validates eligible scan/output-header provenance;
LAST_REFRESH remains the source scan date, not recovery execution time.

Successful repetition reads the durable receipt and does not refresh again.
A timeout/disconnect is unresolved until the receipt is checked. Do not switch to
another recovery, clear rows manually, or blindly replay the old producer.

## Review and operator order

1. Review and merge this SQL PR. No automatic merge. This is an incident recovery,
   not the general deployment workflow or live acceptance of the release runner.
2. Build the single operator script from the reviewed checkout:

   ```powershell
   python deploy\recovery\s11_manual_stats_20261008\build_recovery.py "$env:TEMP\Recover-S11Stats-20261008.ps1"
   ```

   The builder prints its SHA256 and refuses to overwrite an existing output.
   Supply that exact file and hash to the operator. No hand-edited parameters.
3. Copy **that one file** to `C:\Users\cwatt\Downloads` on **MINI_AMD**.
4. Open **Windows PowerShell 5.1 as Administrator**, signed in as MINI_AMD\cwatt.
   Verify its hash matches the supplied build, then execute:

   ```powershell
   & 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\cwatt\Downloads\Recover-S11Stats-20261008.ps1' -Apply
   ```

5. Return the printed `S11-manual-stats-result-*.json`. Success is
   `COMMITTED_MANUAL_SUPERSESSION` or `ALREADY_COMMITTED_NO_REPLAY`.
   Confirm the next scheduled stats refresh loads a valid cache and is no longer
   refused by the c983 hold. Provider/export acceptance is separate; a SQL recovery
   receipt alone does not establish provider delivery or cache refresh.

If a guard fails, inspect the saved exact error. Do not alter the guard to match
unreviewed live state. Locks fail promptly; SQL command timeout is 180 seconds,
connection timeout 5 seconds, row-lock timeout 2 seconds. Existing stats procedure
application locks can wait up to 60 seconds each. No automatic retry is performed.
Transaction failure rolls back database changes unless acknowledgement was lost
after commit; the durable receipt distinguishes that case on a reviewed repeat.

## Validation

`python deploy/recovery/s11_manual_stats_20261008/test_recovery.py` uses only
`9SX2VF4\K98DEV`, a fresh synthetic database and Windows authentication. Ten native
tests cover atomic success, stale fence, competing locks/open stream, invalid
candidate, procedure hash mismatch, producer rollback and repeat after discarded
receipt. One test uses the unchanged canonical stats procedure, lock helper and
stats table with synthetic source/header tables, verifies stale-header refusal,
then succeeds. Fixture databases are retained and their names printed.

These tests do not claim a complete production-schema rehearsal or production
success. Review all touched constraints and mutex namespaces against sql_schema.
Bot architecture/deferred/test-selection/security-routing scripts are skipped for
this SQL-only branch: no bot code or bot reference changes are included. Security
review is a Changes review of this SQL branch; Deep is off.

Full updater simplification remains outstanding. Routine patches must not require
bespoke packet construction; provide a fixed-command builder/update workflow or
revisit the coordinated startup source policy. Recovery is the immediate priority.
