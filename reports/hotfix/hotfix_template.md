# SQL Hotfix Incident Report

Hotfix ID:
Date/time UTC:
Operator:
Environment:
Server:
Database:
Related bot issue/PR:
Related SQL issue/PR:

## 1. Incident Summary

What happened?

What was the user/business impact?

Why was this urgent?

## 2. Decision To Bypass Standard SQL PR Flow

Why could the normal Git-first process not be followed first?

Who approved the emergency path?

What risk was accepted?

## 3. Backup Confirmation

Last full backup:

Last differential backup:

Last log backup:

Backup readiness command/output reference:

Backup readiness warnings:

Any override used:

## 4. Production Change Applied

Exact SQL executed or script path:

Execution time UTC:

Rows affected:

Objects affected:

Transaction handling used:

## 5. Validation Performed

Pre-change validation:

Post-change validation:

Bot smoke test if relevant:

SQL smoke test:

User-visible confirmation:

## 6. Drift And Export Evidence

Export snapshot path:

Drift report path:

Expected drift summary:

Unexpected drift summary:

## 7. Git Reconciliation

Migration created:

Rollback classification:

Rollback script:

Schema snapshot updated:

SQL validation result:

SQL PR:

Merge commit:

Pre-deployment pending migration check:

Deployment result:

Deployment history check:

Post-deployment pending migration check:

Final drift check result:

## 8. Rollback / Forward-Fix Notes

Could this change be rolled back?

Rollback script path if any:

Forward-fix plan if rollback is not safe:

Restore-from-backup decision point:

## 9. Final Status

Final status:

Choose one:

- resolved and reconciled
- resolved with accepted documented drift
- reverted
- monitoring
- incomplete, with owner-run steps listed

Outstanding risks:

Follow-up tasks:

Deferred optimisations:
