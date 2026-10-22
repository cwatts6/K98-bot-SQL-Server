# Reporting continuation permission boundary

The public reporting entry point validates the exact committed preparation before its
static archive call. Ownership chaining permits that call while direct application archive
execution and claim-table reads remain denied. The private reporting core retains its
public EXECUTE denial and revalidates every stage transaction. Import and business
calculation definitions are unchanged.

Migration `20261022_003_stats_report_recovery_boundary` changes only the reporting wrapper.
Its exact preimage, module execution context, schema lock, closed authority and snapshot
writer guard must verify. The coordinated adapter profile
`20261022_004_stats_report_boundary_release` admits only that script and module image,
retains existing permission rows, and records child and outer receipts atomically.
Do not run it against production independently of the paired protected bot updater release.

Validation uses disposable local databases and the restricted application user. Direct
archive/core execution and claim-table SELECT must fail; guarded continuation must preserve
committed stage receipts. A source-defined metadata reference and separate migration fixture
must agree before packaging. The original import is never replayed. No production merge,
deployment or functional acceptance is performed by this change.
