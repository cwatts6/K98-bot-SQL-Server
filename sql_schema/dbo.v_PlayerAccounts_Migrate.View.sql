SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW [dbo].[v_PlayerAccounts_Migrate]  AS
SELECT
    PA.GovernorID,
    COALESCE(n.GovernorName,LTRIM(RTRIM(PA.GovernorName)))           AS GovernorName,   -- fix bad LTRIM(..., 1)
    PP.Power,
    KS4.[Troops Power],
    PA.[Status],
    PA.[UpdatedAt],
    PA.[AccountType],
    PA.[Main_GovernorID],
    loc.X,
    loc.Y
FROM dbo.PlayerAccountStatus AS PA
LEFT JOIN dbo.v_ReportGovernorNames n ON n.GovernorID=PA.GovernorID
OUTER APPLY
(
    -- Latest known location for this governor (prevents duplicate rows)
    SELECT TOP (1) pl.X, pl.Y
    FROM dbo.PlayerLocation AS pl
    WHERE pl.GovernorID = PA.GovernorID
    ORDER BY pl.[LastUpdated] DESC
) AS loc
INNER JOIN dbo.v_PlayerProfile     AS PP  ON PP.GovernorID  = PA.GovernorID
INNER JOIN dbo.v_PlayerLatestStats AS KS4 ON KS4.GovernorID = PA.GovernorID
WHERE PA.[Status] = 'Migrate';
