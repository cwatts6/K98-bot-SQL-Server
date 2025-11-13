SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sp_RefreshInactiveGovernors]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[sp_RefreshInactiveGovernors] AS' 
END
ALTER PROCEDURE [dbo].[sp_RefreshInactiveGovernors]
WITH EXECUTE AS CALLER
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Optional: Log the start of execution
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, StartTime)
        VALUES ('sp_RefreshInactiveGovernors', 'Started', GETDATE());

        -- Step 1: Clear existing inactive governors
        TRUNCATE TABLE INACTIVE_GOVERNORS;

        -- Step 2: Insert new inactive governors
        INSERT INTO INACTIVE_GOVERNORS (GovernorID, GovernorName, [Power], Inactive_Date, [Status])
        SELECT 
            latest.GovernorID,
            RTRIM(ks.GovernorName) AS [GovernorName],
            ks.Power,
            ks.ScanDate AS Inactive_Date,
            'Inactive / Migrated' AS Status
        FROM (
            SELECT GovernorID, MAX(ScanDate) AS LastLogin
            FROM KingdomScanData4
            GROUP BY GovernorID
            HAVING MAX(ScanDate) <= DATEADD(DAY, -1, GETDATE())
               AND MAX(ScanDate) > DATEADD(DAY, -100, GETDATE())
        ) AS latest
        CROSS APPLY (
            SELECT TOP 1 RTRIM(GovernorName) AS GovernorName, Power, ScanDate
            FROM KingdomScanData4 k
            WHERE k.GovernorID = latest.GovernorID
              AND k.ScanDate = latest.LastLogin
            ORDER BY k.ScanDate DESC
        ) AS ks;

        -- Optional: Log success
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, EndTime)
        VALUES ('sp_RefreshInactiveGovernors', 'Success', GETDATE());

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        -- Rollback on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Log error if needed
        INSERT INTO SP_ExecutionLog (ProcedureName, Status, ErrorMessage, EndTime)
        VALUES (
            'sp_RefreshInactiveGovernors',
            'Error',
            ERROR_MESSAGE(),
            GETDATE()
        );

        -- Optionally re-raise the error
        THROW;
    END CATCH
END;

