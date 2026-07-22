/*
RollbackForMigrationId: 20260721_005_add_leadership_player_last_active
Purpose: Remove the additive leadership Last Active procedure after the bot no longer depends on it
Author: cwatts
CreatedUtc: 2026-07-21

Operational order:
1. Roll back and restart the bot.
2. Confirm /stats player is using the accepted Phase 8 contract.
3. Run this rollback.
*/

DROP PROCEDURE IF EXISTS dbo.usp_GetLeadershipPlayerLastActive;
