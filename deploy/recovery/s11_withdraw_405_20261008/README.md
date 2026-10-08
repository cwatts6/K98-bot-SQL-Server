# Withdraw unclaimed S11 ticket405

The 19:53 UTC bounded queue observation found one remaining fairness blocker:
preparation340b9372-e6ee-44de-927a-d10483eefe1a, ticket405, pending/version1,
ownerNULL/fence0, created/updated14:45:24.378, no output/spool/job or stream.
Six captured/materialized preparations are preserved and do not match the
pending/sql_pending fairness predicate. No other ready job/output operation was
observed through ticket465. This does not establish later queue state atomically.

This follows the existing withdraw_unstarted DAL transition, narrowed to the
exact never-claimed row, request hash and timestamps. In one account-mutex-owned
transaction it rechecks state and absence of any linked stream/resource, requires
the prior successful supersession receipt, marks only this preparation unavailable
with a new owner/fence/version and retains an audit. It does not release resources,
execute a producer, change procedures/permissions/flags, or touch captured work.
If a concurrent worker claimed it, the comparison fails with no withdrawal.
An acknowledged repeat returns the receipt with no further change.

## Operator sequence

After reviewed PR merge, use the supplied single generated
`Withdraw-S11Queue405-20261008.ps1` file. Build-time command for the release author:

```powershell
python deploy\recovery\s11_withdraw_405_20261008\build_withdrawal.py "$env:TEMP\Withdraw-S11Queue405-20261008.ps1"
```

Copy the supplied file to MINI_AMD `C:\Users\cwatt\Downloads` and verify the supplied
SHA256. In Windows PowerShell5.1 as Administrator under MINI_AMD\cwatt:

```powershell
& 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\cwatt\Downloads\Withdraw-S11Queue405-20261008.ps1' -Apply
```

Return its JSON. After `WITHDRAWN_UNCLAIMED_PREPARATION` or
`ALREADY_WITHDRAWN_NO_CHANGE`, run `/kvk_admin refresh_stats_cache` once and return
the command reply/log. No restart, supersession rerun or old import/export replay.
Errors/timeouts require receipt review, never an assumption of rollback.

## Validation and limitations

Seven native local-only tests pass: success/repeat without producer or resource
mutation, claimed-row rejection, active resource rejection, even closed stream
rejection, wrong request hash, missing prior receipt and account-mutex contention.
The test fixture uses synthetic coordination tables, not a production clone.
Column/state/owner/JSON constraints and mutex namespace were checked against the
authoritative SQL snapshots and deployed DAL. No production execution performed.
The generated wrapper reuses the reviewed prior operator host/SID/policy/output
handling; build removes unused procedure-hash parameters and changes only the
embedded worker, recovery/result identity and operator status text.

Bot architecture/deferred/test-selection/import/registration/security-routing
validators are skipped for this SQL-only recovery branch. Security review uses
Changes, Deep off. The general orphan-queue prevention/automatic reconciliation
and simple routine-update tooling remain follow-up work; this one-row withdrawal
does not claim to implement those broader changes.
