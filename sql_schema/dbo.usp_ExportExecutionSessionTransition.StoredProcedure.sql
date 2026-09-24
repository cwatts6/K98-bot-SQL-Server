SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
-- S11 reference snapshot. Install the reviewed migration, never this file.
GO
CREATE PROCEDURE dbo.usp_ExportExecutionSessionTransition
 @SessionID uniqueidentifier,
 @Action varchar(16),
 @ExpectedVersion bigint,
 @HostIdentity varchar(128)=NULL,
 @BootID uniqueidentifier=NULL,
 @ExecutableHash binary(32)=NULL,
 @ManifestHash binary(32)=NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51700,'Evidence transition requires its own short transaction.',1;
 IF IS_ROLEMEMBER(N'ExportExecutionAuthority')<>1 OR IS_ROLEMEMBER(N'ExportExecutionAuthority') IS NULL
   THROW 51700,'Evidence authority role required.',1;
 BEGIN TRANSACTION;
 BEGIN TRY

 DECLARE @Existing bigint;
 SELECT @Existing=Version FROM dbo.ExportExecutionSession WITH (UPDLOCK,HOLDLOCK) WHERE SessionID=@SessionID;
 IF @Action='open' AND DATALENGTH(@Action)=4 AND @ExpectedVersion=0 AND @Existing IS NULL
 BEGIN
  INSERT dbo.ExportExecutionSession VALUES (@SessionID,USER_NAME(),@HostIdentity,@BootID,@ExecutableHash,@ManifestHash,1,'open',1,SYSUTCDATETIME(),NULL);
 END
 ELSE IF @Action='close' AND DATALENGTH(@Action)=5 AND @ExpectedVersion=@Existing
 BEGIN
  IF EXISTS (SELECT 1 FROM dbo.ExportExecutionStream WHERE SessionID=@SessionID AND State<>'closed')
    THROW 51700,'Provider stream closure is unproven.',1;
  UPDATE dbo.ExportExecutionSession SET State='closed',Version=Version+1,ClosedUTC=SYSUTCDATETIME()
  WHERE SessionID=@SessionID AND AuthorityPrincipal=USER_NAME() AND State='open' AND Version=@ExpectedVersion;
  IF @@ROWCOUNT<>1 THROW 51700,'Session CAS lost.',1;
 END
 ELSE THROW 51700,'Session action/CAS conflict; read exact identity before retry.',1;
 SELECT * FROM dbo.ExportExecutionSession WHERE SessionID=@SessionID;
 COMMIT;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  THROW;
 END CATCH;
END;
