SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- Bootstrap only. Existing KVK bindings are updated by a reviewed migration.
IF OBJECT_ID(N'dbo.v_TARGETS_FOR_UPLOAD', N'V') IS NULL
BEGIN
    EXEC(N'CREATE VIEW dbo.v_TARGETS_FOR_UPLOAD AS
SELECT t.[Rank],
    t.[Gov_ID],
    COALESCE(n.GovernorName,t.[Governor_Name]) AS [Governor_Name],
    t.[Power],
    t.[City Hall],
    t.[Troops Power],
    t.[Tech Power],
    t.[Building Power],
    t.[Commander Power],
    t.[BLANK1],
    t.[Kill Target],
    t.[Minimum Kill Target],
    t.[Dead Target],
    t.[DKP Target],
    t.[BLANK2],
    t.[Kills KVK -1],
    t.[DEADS KVK -1],
    t.[DKP KVK -1],
    t.[% DKP Target KVK -1],
    t.[BLANK3],
    t.[Kills KVK -2],
    t.[DEADS KVK -2],
    t.[DKP KVK -2],
    t.[% DKP Target KVK -2]
FROM dbo.EXCEL_EXPORT_KVK_TARGETS_15 t
LEFT JOIN dbo.v_ReportGovernorNames n ON n.GovernorID=t.Gov_ID;');
END;
