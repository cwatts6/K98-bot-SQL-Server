/*
RollbackForMigrationId: 20260605_001_add_player_overall_kvk_rank_view
Purpose: Drop SQL-backed overall KVK rank view
Author: cwatts
CreatedUtc: 2026-06-05
*/

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID(N'KVK.vw_Player_Overall_KVK_Rank', N'V') IS NOT NULL
BEGIN
    DROP VIEW [KVK].[vw_Player_Overall_KVK_Rank];
END
GO
