SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_update_stats @RequestID uniqueidentifier = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2 THROW 51962, 'Post-import maintenance requires autocommit.', 1;
    EXEC dbo.usp_MaintenanceDue @Kind='post_import',@RequestID=@RequestID;
    EXEC dbo.usp_RunMaintenance @Kind='import';
    EXEC dbo.usp_RunMaintenance @Kind='configuration';
    EXEC dbo.usp_RunMaintenance @Kind='player_report';
    EXEC dbo.usp_RunMaintenance @Kind='kvk_output';
    EXEC dbo.usp_RunMaintenance @Kind='final_stats';
    EXEC dbo.usp_RunMaintenance @Kind='post_import';
    SELECT Kind,DueGeneration,CompletedGeneration,ClaimedGeneration,ClaimID,
        State,FirstErrorNumber,LastErrorNumber
      FROM dbo.MaintenanceWork WHERE Kind IN ('import','configuration','player_report','kvk_output','final_stats','post_import');
END;
