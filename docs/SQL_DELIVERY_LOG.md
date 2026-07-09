# SQL Delivery Log

This file records notable SQL delivery milestones that are useful to bot task-pack closeout and
promotion review. Migration files and `dbo.SchemaMigrationHistory` remain the source of truth for
what has actually been deployed.

## Discord Voting Post Framework

| Date | Migration / PR | Status | Notes |
|---|---|---|---|
| 2026-07-04 | `20260704_003_add_survey_ranking_questions` / SQL PR #33 | Deployed to production | Added complete ranking question SQL support through `dbo.SurveyRankingAnswers`, `Ranking` question-type constraints, per-response/question option/rank uniqueness, aggregate-friendly indexes, and deployment-order compatibility for the Phase 9C bot slice. Bot smoke testing confirmed ranking survey creation, required ranking submission, optional ranking skip/clear, ranking update/regression behavior, aggregate-only public cards, and compatibility with existing vote/survey behavior. |

## Import Pipeline

| Date | Migration / PR | Status | Notes |
|---|---|---|---|
| 2026-07-09 | `20260709_001_add_update_all2_audit_outputs` / SQL PR #41 | Deployed to production | Added non-invasive `dbo.UPDATE_ALL2` phase audit output rows while preserving output tables, `SP_TaskStatus` polling, and the final 8-column summary result set consumed by the bot. Bot PRs #215/#522 parse and persist the phase rows through generic `ImportAuditPhase`. Production smoke confirmed fallback batch 67 completed normally, emitted 13 `update_all2_*` subphase rows, identified `update_all2_summary_proc` as the dominant first-sample visible subphase at about 78 seconds, and showed no `_update_all2_phase_results` leakage after the bot review-fix restart. Follow-up work is evidence review before any `SUMMARY_PROC` or `UPDATE_ALL2` decomposition. |
