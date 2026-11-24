SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER PROCEDURE dbo.usp_P02EndCatalogueMutation
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT<>0 OR (@@OPTIONS & 2)=2
        THROW 51970,'Finish physical work before releasing the session marker.',1;
    IF COALESCE(APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session'),'Unknown')<>'Shared'
        THROW 51970,'Exact session mutation ownership required.',1;
    DECLARE @r int;
    EXEC @r=sys.sp_releaseapplock @Resource=N'K98:catalogue-mutation:v1',@LockOwner='Session';
    IF @r IS NULL OR @r<>0 OR
        COALESCE(APPLOCK_MODE('public','K98:catalogue-mutation:v1','Session'),'Unknown')<>'NoLock'
        THROW 51970,'Catalogue marker release was not acknowledged.',1;
END;
GO
