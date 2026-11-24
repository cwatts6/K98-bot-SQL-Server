SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER dbo.tr_P02MaintenanceObservation ON dbo.MaintenanceWork
AFTER INSERT,UPDATE,DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted WHERE Kind='kvk_output')
       OR EXISTS(SELECT 1 FROM deleted WHERE Kind='kvk_output')
    BEGIN
        BEGIN TRANSACTION;
        EXEC dbo.usp_P02BeginCatalogueMutation @Owner='Transaction';
        COMMIT TRANSACTION;
    END;
END;
GO
