# P02 D4b direct maintenance-child admission

This is the focused D4-R01 correction inside D4b, not completion of D4b or a
production installer. D4a installed consumer evidence, missing sequence/wrapper
definitions, effective backup identities, F31, combined migration and release
qualification remain separate obligations in the accepted D4 scope.

All six maintenance children now reject active or implicit caller transactions
before reading business state or performing upkeep. This matches the existing
usp_RunMaintenance public boundary and prevents direct EXECUTE callers from
moving maintenance into an unrelated transaction.

Import, configuration and post-import children additionally require the exact
session-owned player-publication guard. Post-import calls database-wide
sp_updatestats. Import and configuration both update KingdomScanData4 statistics,
and import may rebuild its indexes; SP_Stats_for_Upload reads that table while
holding K98:StatsForUpload:Publish. The requirement follows those real shared
objects. The other three children already checked that guard.

The existing worker acquisition/release order is unchanged: post-import, legacy
snapshot, delta publication, player publication, maintenance schema. Child
checks do not acquire guards or change their order. No permissions, execution
context, business calculation, maintenance threshold or schedule is broadened.
First-failure handling and retained physical cleanup remain unchanged.

## Verification

- 49 new native cases in a uniquely owned local disposable database: restricted
  direct callers missing each of five mandatory guards across six children;
  active and implicit transaction refusal for all six; denied users; successful
  real post-import statistics execution with all guards.
- Two existing native public-session contract cases also passed (51 total).
- All 71 existing Bot native maintenance cases across the six families passed.
  Existing fixture limitations, including simulated provider responses, remain.
- Five existing SQL business-preservation comparisons passed.
- Offline source custody validates all 23 historical D3 definitions against
  pinned predecessor 0ebe0d3fe099ec62c76333c8b58c9049d93dcece, preserves the exact
  historical checker and its pins, and authenticates six exact D4 successors.
  LF/CRLF, each missing member and each changed member are exercised. CI uses
  this successor check rather than applying the historical D3 postimage to D4.

These test users have only the explicit child EXECUTE grants inside their new
test database. They are not the installed application principal; installed
effective-permission evidence remains required. These source candidates are not
the final combined migration profile and do not authorize installation.

Security routing: SQL Changes review over this exact branch, Deep off. Bot
runtime code is unchanged by this SQL-only correction; its native tests consume
the authoritative SQL source. This adds no deferred optimisation item: it closes
an accepted D4 direct-entry obligation.
