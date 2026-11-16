# Deployment resource requirements: environment and timing

Resource requirements must retain their original environment, measurement and
timing. Do not turn a qualification prerequisite into a production admission
guard because a later handover abbreviates it as a memory/disk reserve.

| Requirement | Where and when it applies |
| --- | --- |
| At least 8 GiB available host memory | Development host **before starting the isolated qualification VM** |
| 4 CPUs / 8 GiB assigned VM RAM / no network adapters | Isolated qualification VM configuration |
| At least 8 GiB available disk | Qualified storage reserve; production release checks every database and tempdb file volume |
| Database log below 70% used | Production release preflight and transaction resource checks |
| Version store below 512 MiB | Production release preflight and transaction resource checks |

The VM-start memory prerequisite is **not** an additional reservation after VM
startup, a free-memory requirement inside the 8 GiB guest, or a production SQL
host admission threshold. Production does not run the qualification VM. A memory
sample alone does not establish a production failure or authorize SQL configuration
changes, process termination, a restart or a reduced threshold. Any new production
memory gate needs an evidenced requirement and separate explicit approval.

The original authority is [Phase 1, Existing limits](archive/p02-phase1-implementation.md#existing-limits-unchanged).
Its table and following paragraph define the pre-start timing. The 16 November
D6 review found that `Assert-K98D4Resources` had incorrectly added a SQL-host
8 GiB free-memory check. That check is removed; the shared Phase 1 disk, log and
version-store checks, exact transaction, dependency checks, migration/profile
bytes, backup evidence, permissions and all 30 object images remain unchanged.

`tests/test_d4_release_runner.ps1` exercises the production functions with a
transport double that rejects any VM-memory query and verifies retained resource
thresholds, transaction propagation and refusal handling. This test must fail if
the misplaced production guard is restored. Do not update the test to accept a
second memory query without revisiting the original approved requirement.

Keep original receipts and withdrawn interpretations. A correction changes the
current disposition; it does not rewrite first-failure evidence or consume/replay
accepted qualification. A new helper commit still requires exact Bot release
bindings and review; editing a deployed or already-pinned package is not a fix.
