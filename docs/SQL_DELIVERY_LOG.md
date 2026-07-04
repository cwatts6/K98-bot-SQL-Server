# SQL Delivery Log

This file records notable SQL delivery milestones that are useful to bot task-pack closeout and
promotion review. Migration files and `dbo.SchemaMigrationHistory` remain the source of truth for
what has actually been deployed.

## Discord Voting Post Framework

| Date | Migration / PR | Status | Notes |
|---|---|---|---|
| 2026-07-04 | `20260704_003_add_survey_ranking_questions` / SQL PR #33 | Deployed to production | Added complete ranking question SQL support through `dbo.SurveyRankingAnswers`, `Ranking` question-type constraints, per-response/question option/rank uniqueness, aggregate-friendly indexes, and deployment-order compatibility for the Phase 9C bot slice. Bot smoke testing confirmed ranking survey creation, required ranking submission, optional ranking skip/clear, ranking update/regression behavior, aggregate-only public cards, and compatibility with existing vote/survey behavior. |
