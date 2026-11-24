SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_P02BeginCatalogueMutation
    @Owner varchar(11)='Transaction'
AS
BEGIN
    SET NOCOUNT ON;
    IF @Owner NOT IN ('Session','Transaction') OR @Owner IS NULL
        THROW 51970,'Unsupported catalogue mutation owner.',1;
    IF @Owner='Transaction' AND (@@TRANCOUNT=0 OR XACT_STATE()<>1)
        THROW 51970,'A committable mutation transaction is required.',1;
    IF @Owner='Session' AND (@@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2)
        THROW 51970,'Session mutation requires an owned autocommit worker.',1;
    DECLARE @mode nvarchar(32)=APPLOCK_MODE('public','K98:catalogue-mutation:v1',@Owner);
    IF @mode IS NULL OR @mode NOT IN ('NoLock','Shared')
        THROW 51970,'Unexpected catalogue marker ownership.',1;
    -- Nested helpers inherit the marker; never add an unbalanced reference.
    IF @mode='NoLock'
    BEGIN
        DECLARE @r int;
        EXEC @r=sys.sp_getapplock @Resource=N'K98:catalogue-mutation:v1',
            @LockMode='Shared',@LockOwner=@Owner,@LockTimeout=0;
        IF @r IS NULL OR @r NOT IN (0,1)
            THROW 51970,'Catalogue mutation marker was not acknowledged.',1;
    END;
    DECLARE @generation bigint=NEXT VALUE FOR dbo.P02ObservationGeneration;
    IF @generation<=1 THROW 51970,'Observation sequence was not bootstrapped.',1;
END;
GO
