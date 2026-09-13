/*
MigrationId: 20260913_002_kvk_source_admin_reviews
Purpose: Add durable owner-scoped S8C intake and configuration reviews
Author: cwatts
CreatedUtc: 2026-09-13
RequiresBackup: Yes
RiskLevel: Low
Rollback: Forward Fix Only
RollbackScript: N/A
TransactionMode: Auto
DataChange: No
DataSafetyPlan: Not Required
EstimatedRowsAffected: N/A
PreValidationQuery: N/A
PostValidationQuery: SELECT OBJECT_ID('KVK.SourceAdminReview','U')
RelatedBotPR:
RelatedSQLPR:
*/
-- Authoring only. No execution/deployment authorized by the S8C implementation approval.
-- Deploy after S8A/S8B and before enabling revised intake. Never delete retained reviews
-- as rollback: disable intake and forward-fix; previous Bot versions ignore this table.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF OBJECT_ID(N'KVK.SeasonSource',N'U') IS NULL
    THROW 51000, 'S8A season-source schema is required.', 1;
IF OBJECT_ID(N'KVK.SourceAdminReview',N'U') IS NULL
BEGIN
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;

-- S8C reference snapshot. Deploy only the separately approved migration.
CREATE TABLE KVK.SourceAdminReview
(
    ReviewID uniqueidentifier NOT NULL,
    ReviewSequence bigint IDENTITY(1,1) NOT NULL,
    KVK_NO int NOT NULL,
    ReviewKind varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ActorID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,
    GuildID nvarchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    ChannelID nvarchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    Version bigint NOT NULL,
    ReviewState varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,
    PayloadJson nvarchar(max) NOT NULL,
    PayloadHash binary(32) NOT NULL,
    OutcomeJson nvarchar(max) NULL,
    CreatedUTC datetime2(0) NOT NULL,
    ExpiresUTC datetime2(0) NOT NULL,
    CompletedUTC datetime2(0) NULL,
    CONSTRAINT PK_SourceAdminReview PRIMARY KEY (ReviewID),
    CONSTRAINT CK_SourceAdminReview_Kind CHECK (ReviewKind IN ('choose_source','intake','match_update','configuration') AND DATALENGTH(ReviewKind)=LEN(ReviewKind)),
    CONSTRAINT CK_SourceAdminReview_Scope CHECK (KVK_NO>0 AND Version>0 AND LEN(ActorID)>0 AND LEN(GuildID)>0 AND LEN(ChannelID)>0),
    CONSTRAINT CK_SourceAdminReview_Payload CHECK (ISJSON(PayloadJson)=1 AND DATALENGTH(PayloadJson)<=65536),
    CONSTRAINT CK_SourceAdminReview_Outcome CHECK (OutcomeJson IS NULL OR (ISJSON(OutcomeJson)=1 AND DATALENGTH(OutcomeJson)<=65536)),
    CONSTRAINT CK_SourceAdminReview_State CHECK (DATALENGTH(ReviewState)=LEN(ReviewState) AND ((ReviewState='pending' AND OutcomeJson IS NULL AND CompletedUTC IS NULL) OR (ReviewState IN ('completed','cancelled') AND OutcomeJson IS NOT NULL AND CompletedUTC IS NOT NULL))),
    CONSTRAINT CK_SourceAdminReview_Time CHECK (ExpiresUTC>CreatedUTC AND (CompletedUTC IS NULL OR CompletedUTC>=CreatedUTC))
);
CREATE INDEX IX_SourceAdminReview_Owner ON KVK.SourceAdminReview (ActorID,GuildID,ChannelID,ReviewState,CreatedUTC) INCLUDE (KVK_NO,ReviewKind);
-- No SeasonSource FK: a choose_source review necessarily precedes the fixed choice.
-- Writer services enforce season existence, immutable payload, ownership and CAS.

END;


