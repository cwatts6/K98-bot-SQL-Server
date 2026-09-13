-- S8C disposable-only review constraints. Authoring only; exact target/execution approval required.
-- No existing table data is deleted and no retained predecessor database is a valid target.
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE 'K98[_]S8C[_]Disposable[_]%'
    THROW 51000, 'An explicitly approved S8C disposable database is required.', 1;
IF @@TRANCOUNT <> 0
    THROW 51000, 'Run this rollback fixture in its own approved session.', 1;
DECLARE @ReviewID uniqueidentifier = NEWID();
BEGIN TRANSACTION;
BEGIN TRY
    INSERT KVK.SourceAdminReview
      (ReviewID,KVK_NO,ReviewKind,ActorID,GuildID,ChannelID,Version,ReviewState,PayloadJson,PayloadHash,CreatedUTC,ExpiresUTC)
    VALUES (@ReviewID,2000000001,'choose_source','synthetic-admin','synthetic-guild','synthetic-channel',1,'pending',N'{"source":"snapshot_report_v1"}',CONVERT(binary(32),0x01),'2000-01-01','2000-01-02');
    IF NOT EXISTS (SELECT 1 FROM KVK.SourceAdminReview WHERE ReviewID=@ReviewID AND ReviewSequence>0)
        THROW 51000, 'Review identity was not retained.', 1;
    UPDATE KVK.SourceAdminReview SET Version=Version+1,ReviewState='cancelled',OutcomeJson=N'{"state":"cancelled"}',CompletedUTC='2000-01-01T01:00:00'
      WHERE ReviewID=@ReviewID AND Version=1 AND ReviewState='pending';
    IF @@ROWCOUNT<>1 THROW 51000, 'First cancellation CAS failed.', 1;
    UPDATE KVK.SourceAdminReview SET Version=Version+1 WHERE ReviewID=@ReviewID AND Version=1;
    IF @@ROWCOUNT<>0 THROW 51000, 'Stale review CAS succeeded.', 1;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
IF EXISTS (SELECT 1 FROM KVK.SourceAdminReview WHERE ReviewID=@ReviewID)
    THROW 51000, 'Synthetic rows survived rollback: SourceAdminReview', 1;
PRINT 'S8C review identity, state, CAS and rollback fixture passed.';
