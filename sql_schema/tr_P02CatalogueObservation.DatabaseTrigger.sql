SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER TRIGGER tr_P02CatalogueObservation ON DATABASE
FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;
    -- EVENTDATA XML methods require these options independently of the DDL caller.
    -- Trigger scope restores the caller's options on return, including warnings OFF.
    SET ANSI_NULLS ON;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET ARITHABORT ON;
    SET CONCAT_NULL_YIELDS_NULL ON;
    SET NUMERIC_ROUNDABORT OFF;
    DECLARE @event xml=EVENTDATA();
    -- Never permit reset/replacement of an admitted counter. A drained migration
    -- must explicitly remove this protection and create a new contract identity.
    IF @event.value('(/EVENT_INSTANCE/SchemaName)[1]','sysname')='dbo'
       AND @event.value('(/EVENT_INSTANCE/ObjectName)[1]','sysname')='P02ObservationGeneration'
        THROW 51970,'Observation sequence changes require a drained contract migration.',1;
    -- Autocommit DDL trigger context can have a nesting count without a user
    -- transaction usable by APPLOCK_MODE (native SQL3918). Explicitly nest;
    -- the enclosing statement/transaction must retain the marker to completion.
    -- Qualification includes a later-trigger barrier to prove that lifetime.
    BEGIN TRANSACTION;
    EXEC dbo.usp_P02BeginCatalogueMutation @Owner='Transaction';
    COMMIT TRANSACTION;
END;
GO
