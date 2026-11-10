SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_MaintenanceDue
    @Kind varchar(24), @RequestID uniqueidentifier = NULL, @ImportKS4 bit = 0
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    IF @ImportKS4=1 AND @Kind<>'import' THROW 51962,'KS4 scope requires import maintenance.',1;
    -- Join the business transaction. Never commit or roll back the caller.
    -- The finite row set coalesces work; no per-import queue grows without bound.
    UPDATE dbo.MaintenanceWork WITH (UPDLOCK)
       SET DueGeneration=DueGeneration+1, DueUTC=SYSUTCDATETIME(),
           KS4DueGeneration=CASE WHEN @ImportKS4=1 THEN DueGeneration+1 ELSE KS4DueGeneration END,
           LastRequestID=@RequestID,
           State=CASE WHEN State='complete' THEN 'pending' ELSE State END
     WHERE Kind=@Kind AND (@RequestID IS NULL OR LastRequestID IS NULL
                          OR LastRequestID<>@RequestID);
    IF NOT EXISTS(SELECT 1 FROM dbo.MaintenanceWork WHERE Kind=@Kind)
        THROW 51962, 'Unknown maintenance kind.', 1;
END;
