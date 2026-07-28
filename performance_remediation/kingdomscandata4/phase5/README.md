# KingdomScanData4 Phase 5 — bot, DAL and immutable file handoff

Status: ready; Phase 4 is closed and the final Phase 3/4 SQL contracts are available. Phase 5 is
the next implementation phase. Bot implementation belongs to the separate repository at
`C:\discord_file_downloader`. The immutable-file protocol also requires a narrowly scoped
companion SQL migration and canonical definition update in this repository.

## Objective

Remove bot-side SQL compensation made obsolete by the corrected SQL contracts while preserving
every public, DAL, import, export, ordering, null and fallback behavior. Close the two Phase 3
Low/P3 mutable-path findings by binding producer publication, SQL claim, digest, import, receipt
and archive to one immutable, uniquely named file.

## Repository and architecture rules

- Create a dedicated bot mirror branch and PR; do not place Python changes in the SQL repository.
- Validate every SQL assumption against `C:\K98-bot-SQL-Server`.
- Data access belongs in DAL/repository modules; commands and views remain SQL-free.
- Promote the validated mirror delta through the patch-based production flow and deploy only from
  `K98-bot/main`.
- The SQL and bot repositories require separate test and diff-security evidence.
- Do not combine the repositories into an invented Git diff. Freeze one exact SQL commit and one
  exact bot commit for the combined release receipt.

## Approved changes

1. `player_self_service/accounts_dal.py`
   - use direct `bigint` GovernorID selection/partition/join expressions;
   - remove only newly redundant integer-metric conversions;
   - preserve the 22-column contract, nulls, ascending SQL order, account-slot remap and five-ID
     scenario.
2. `player_self_service/governor_dashboard_dal.py`
   - replace the float governor predicate with a direct `bigint` predicate;
   - remove only casts made redundant by final integer types;
   - preserve the exact-one-row 19-column contract, freshness/latest precedence and
     present/absent behavior.
3. `weekly_activity_importer.py`
   - use direct `bigint` governor values and remove the obsolete `nvarchar(255)` alliance
     conversion;
   - preserve blank-alliance normalization, date conversion, allied-cohort and completion-state
     semantics.
4. `embed_offseason_stats.py`
   - move the touched direct SQL into a dedicated stats-alert DAL;
   - remove only redundant `Power AS bigint` casts;
   - preserve daily/weekly totals, limits, ordering, fallbacks and all six leaderboard contracts.

No source change is planned for `kvk_state.py`, `kvk/dal/kvk_history_dal.py`,
`stats/dal/fallback_import_dal.py` or `leadership_player_review/dal.py` while their mapped
contracts remain unchanged. Their exact smokes remain mandatory.

## Immutable file-handoff remediation

The following two findings are one root-cause family and must close together:

- `csf_1a1c440452b02cdb787fa7c3`: source hash and `BULK INSERT` can observe different bytes.
- `csf_3cb54318733d3a216dd91e9b`: source hash and archive `MOVE` can observe different bytes.

The approved design requirements are:

1. The bot writes to a private temporary name, closes the file, then atomically publishes a
   unique completed name.
2. SQL claims that exact completed name; the reusable `stats.csv` pathname is no longer the work
   identity.
3. Producer and directory ACL behavior prevents replacement or mutation after claim.
4. Hashing, `BULK INSERT`, the receipt and archival all carry the claimed immutable identity.
5. The archive destination is derived from the claim and rehashed before the receipt advances.
6. Duplicate retry, invalid/corrected retry, controlled failure, reconciliation and crash recovery
   remain deterministic.
7. The SQL companion migration is backward/forward ordered for a stopped-writer maintenance
   window and has an exact rollback definition.

## Required tests

- Update `tests/test_player_self_service_accounts_dal.py`.
- Update `tests/test_governor_dashboard_dal.py`.
- Update `tests/test_weekly_activity_importer.py`,
  `tests/test_weekly_activity_upload_route.py` and weekly/import audit coverage.
- Add focused tests for the new stats-alert DAL and retain the owning embed smoke.
- Run every scenario in the SQL repository's `phase1/bot_dal_contract_map.md`.
- Run architecture, deferred-item, test-selection, smoke-import, command-registration,
  security-routing, pre-commit and full pytest gates.
- Confirm pytest did not mutate production operational logs.
- Run a bot-repository Changes security review against the final committed diff.
- Run a separate SQL-repository Changes security review for the companion migration. Both scans
  must validate closure of the two stable finding IDs.

## Exit gate

Phase 5 closes only when the four approved paths are implemented, every changed and
source-unchanged contract smoke passes, the full bot suite is clean, both repository-specific
security reviews are complete, both mutable-path findings are closed, and the exact SQL and bot
commits are ready for the combined release rehearsal.
