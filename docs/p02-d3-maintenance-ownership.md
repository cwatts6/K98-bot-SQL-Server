# P02 D3b: bounded durable maintenance ownership

This is the SQL companion to the Bot D3b maintenance ownership slice. The
operator authorized completing D3b–g, merging focused Bot mirror PRs, and creating
and reviewing the combined private Bot PR. Production installation remains held
until after D5. No production SQL, provider, retained recovery or restart was run.

## Contract

`dbo.MaintenanceWork` has six fixed rows. `dbo.usp_MaintenanceDue` joins its
caller's transaction and coalesces due generations. It neither commits nor
rolls back an outer business transaction. A same latest request ID does not add
another generation; this is not general historic request replay authority.

`dbo.usp_RunMaintenance` is autocommit-only. Its actual worker session acquires
the existing `K98:post-import-stats:v1` lock and the existing SQL snapshot writer
guard without waiting. Retaining the older maintenance resource prevents overlap
with older callers. Known log use below 70 percent is required before claim.
Only pending work runs. A free worker lock with a durable running claim changes
the claim to unknown; it does not retry the child. Failed/unknown states retain
the original claim and first failure for reviewed reconciliation. New due work
during a claim remains pending after completion of that generation.

`dbo.usp_update_stats` records post-import work and invokes the worker. Its
result contains the finite durable receipt, consumed by the matching Bot DAL.
`dbo.usp_MaintenancePostImport` retains the intentional `sp_updatestats` child
under owner execution and checks both worker guards. Resource observation runs
in the caller context: placing that DMV inside database-owner impersonation
failed native qualification with SQL 15562. No TRUSTWORTHY change or new server
grant was used to bypass that boundary. SQL error paths retain guards until the
dedicated physical connection closes; the Bot retains uncertain cleanup.

## Qualification and remaining scope

Nine opted-in native tests passed on 10 November 2026 using only a uniquely
created local disposable database. They exercise real `sp_updatestats`, durable
receipts, exact latest-request deduplication, outer rollback/nested-commit
visibility, concurrent exclusion, producer-first and maintenance-first arrival,
generation arrival during the real child, child fault injection, process death,
and refusal of a missing child or caller transaction. Process death accepts only
the two evidenced outcomes: durable completion before disconnect is observed,
or an unknown claim; neither allows blind replay. Injected gates/errors are
fixture-only and are distinguished from unchanged child execution.

The Bot tests are `tests/test_maintenance_owned_native.py` and
`tests/test_maintenance_dal.py` in the companion repository. The native fixture
requires `K98_P021_NATIVE_SQL=CREATE_DISPOSABLE_LOCAL_ONLY` and verifies the fixed
local server identity before creating a UUID-named database. It never force
disconnects retained sessions or changes server/database isolation settings.

D3c–g add the other real children and due boundaries. D3g owns backup queue
claim/acknowledgement and post-success wait separation. Raw-history SNAPSHOT
versus index REBUILD (SQL 3961) remains open until D3c's actual overlap tests.
All existing 8 GiB memory/disk floors, log/version-store limits and D5 balanced
cost gates remain in force. This small fixture does not qualify production
scale, restricted installed principals or the combined workflow.

These schema snapshots are source candidates, not an installer. D4 must include
the exact predecessor/postimage deployment and signing profiles, dependencies,
new procedure permissions, installed/manual paths and coordinated Bot/SQL
compatibility. Do not run these files piecemeal in production. No downgrade that
discards outstanding maintenance records is authorized. Separate Bot/SQL Changes
security reviews and PR checks remain required before merge.
