/* Transaction-only registration constraint cases. No provider/production data.
   Run against an isolated local fixture; SQL object name/type cross-checks remain separate. */
SET NOCOUNT ON; SET XACT_ABORT ON;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
IF @@TRANCOUNT<>0 THROW 51726,'Own validation transactions required',1;
CREATE TABLE #FileIdentityCases(FileID nvarchar(128) COLLATE Latin1_General_100_BIN2 NOT NULL,CHECK(DATALENGTH(FileID) BETWEEN 6 AND 256 AND FileID NOT LIKE N'%[^-A-Za-z0-9_]%' COLLATE Latin1_General_100_BIN2));
CREATE TABLE #SlotDispositionCases(LastDispositionID uniqueidentifier NULL,LastAction varchar(32) COLLATE Latin1_General_100_BIN2 NULL,LastDispositionVersion bigint NULL,State varchar(32) COLLATE Latin1_General_100_BIN2 NOT NULL,AssignmentID uniqueidentifier NULL,OwnerID uniqueidentifier NULL,Fence bigint NOT NULL,Version bigint NOT NULL,Epoch bigint NOT NULL,CHECK(((LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'quarantined' AND AssignmentID IS NULL) OR (LastDispositionID IS NOT NULL AND LastAction IS NOT NULL AND DATALENGTH(LastAction) = LEN(LastAction) AND LastDispositionVersion IS NOT NULL AND LastDispositionVersion > 0 AND LastDispositionVersion <= Version AND ((State = 'free' AND LastAction = 'clear') OR (State IN ('staging','active') AND LastAction = 'assign' AND LastDispositionID = AssignmentID) OR (State = 'quarantined' AND LastAction = 'quarantine') OR (State = 'retired' AND LastAction = 'retire'))) OR (LastDispositionID IS NULL AND LastAction IS NULL AND LastDispositionVersion IS NULL AND State = 'free' AND AssignmentID IS NULL AND OwnerID IS NULL AND Fence = 0 AND Version = 1 AND Epoch = 1))));
DECLARE @FileCases TABLE(CaseName varchar(64),FileID nvarchar(256) NULL,Accept bit);
INSERT @FileCases VALUES
 ('index-underscore',N'1oNTj1W2OzdzZP4dpWNwvU3I81qRvnnlcn_uhoI8QVLQ',1),
 ('slot-hyphen',N'1m6R1p4hInf-CtL9bAK-fzc4emB38XoP8ViJEpuI9jA4',1),
 ('slot-both',N'1JsMrUOCav1mQu2570M8tQ7RPauJD6fft_ztLhkx61mE',1),
 ('slot-alphanumeric',N'1CaOblsUbAbhl3iLEubadilIHympxbsUp9u2JXlc8rpQ',1),
 ('slot-underscore-2',N'1zKq3eSCkVd2BTvGkRCTfXa9GenLc8_gCICcNQuKdHsg',1),
 ('minimum',N'a_-',1),('maximum',REPLICATE(N'a',128),1),
 ('too-short',N'ab',0),('too-long',REPLICATE(N'a',129),0),
 ('space',N'abc def',0),('slash',N'abc/def',0),('dot',N'abc.def',0),
 ('unicode',N'abc'+NCHAR(233),0),('percent',N'abc%def',0),('null',NULL,0);
DECLARE @Name varchar(64),@File nvarchar(256),@Accept bit,@Accepted bit,@Passed int=0;
DECLARE F CURSOR LOCAL FAST_FORWARD FOR SELECT CaseName,FileID,Accept FROM @FileCases;
OPEN F;FETCH NEXT FROM F INTO @Name,@File,@Accept;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @Accepted=0;
 BEGIN TRY
  BEGIN TRANSACTION;
  INSERT #FileIdentityCases VALUES(@File);
  SET @Accepted=1;
  ROLLBACK TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  IF ERROR_NUMBER() NOT IN (515,547,8152,2628) THROW;
 END CATCH;
 IF @Accepted<>@Accept THROW 51726,'File identity case outcome differs',1;
 SET @Passed+=1;FETCH NEXT FROM F INTO @Name,@File,@Accept;
END;
CLOSE F;DEALLOCATE F;
DECLARE @SlotCases TABLE(CaseName varchar(64),State varchar(32),OwnerID uniqueidentifier NULL,Fence bigint,Version bigint,Epoch bigint,AssignmentID uniqueidentifier NULL,Recorded bit,Accept bit);
INSERT @SlotCases VALUES
 ('first-verified-free','free',NULL,0,1,1,NULL,0,1),
 ('reused-without-clear','free',NULL,0,2,1,NULL,0,0),
 ('rolled-without-clear','free',NULL,0,1,2,NULL,0,0),
 ('fenced-without-clear','free',NULL,1,1,1,NULL,0,0),
 ('owned-without-clear','free',NEWID(),0,1,1,NULL,0,0),
 ('assigned-without-clear','free',NULL,0,1,1,NEWID(),0,0),
 ('initial-quarantine','quarantined',NULL,0,1,1,NULL,0,1),
 ('recorded-clear','free',NULL,1,2,1,NULL,1,1);
DECLARE @State varchar(32),@Owner uniqueidentifier,@Fence bigint,@Version bigint,@Epoch bigint,@Assignment uniqueidentifier,@Recorded bit;
DECLARE C CURSOR LOCAL FAST_FORWARD FOR SELECT CaseName,State,OwnerID,Fence,Version,Epoch,AssignmentID,Recorded,Accept FROM @SlotCases;
OPEN C;FETCH NEXT FROM C INTO @Name,@State,@Owner,@Fence,@Version,@Epoch,@Assignment,@Recorded,@Accept;
WHILE @@FETCH_STATUS=0
BEGIN
 SET @Accepted=0;
 BEGIN TRY
  BEGIN TRANSACTION;
  INSERT #SlotDispositionCases VALUES(CASE WHEN @Recorded=1 THEN NEWID() END,CASE WHEN @Recorded=1 THEN 'clear' END,CASE WHEN @Recorded=1 THEN 2 END,@State,@Assignment,@Owner,@Fence,@Version,@Epoch);
  SET @Accepted=1;
  ROLLBACK TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK;
  IF ERROR_NUMBER()<>547 THROW;
 END CATCH;
 IF @Accepted<>@Accept THROW 51726,'Slot disposition case outcome differs',1;
 SET @Passed+=1;FETCH NEXT FROM C INTO @Name,@State,@Owner,@Fence,@Version,@Epoch,@Assignment,@Recorded,@Accept;
END;
CLOSE C;DEALLOCATE C;
IF (SELECT COUNT(*) FROM #FileIdentityCases)+(SELECT COUNT(*) FROM #SlotDispositionCases)<>0 OR @@TRANCOUNT<>0
 THROW 51726,'Validation rows or transaction leaked',1;
DROP TABLE #FileIdentityCases,#SlotDispositionCases;
SELECT 'PASSED_REGISTRATION_CONSTRAINT_CASES' AS Status,@Passed AS Cases,@@TRANCOUNT AS RemainingTransactionCount;
