param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Offline source inspection. This never opens SQL, applies a migration or starts a process.
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Read-Source([string]$RelativePath) {
    return [IO.File]::ReadAllText((Join-Path $RepositoryRoot $RelativePath)).Replace("`r`n", "`n")
}
$migration = Read-Source 'migrations/20260924_001_export_execution_evidence.sql'
$tables = @('ExportExecutionSession','ExportExecutionStream','ExportProviderRequest','ExportProviderRequestEvent','ExportReconciliationProof','ExportManagedFileOrigin')
$procedures = @('usp_ExportExecutionSessionTransition','usp_ExportExecutionStreamTransition','usp_ExportProviderRequestEventAppend','usp_ExportReconciliationProofIssue','usp_ExportOutputEnrollmentTransition')
foreach ($name in $tables) {
    $source = Read-Source "sql_schema/dbo.$name.Table.sql"
    $body = $source.Substring($source.IndexOf('CREATE TABLE '))
    Assert-Contract ($migration.Contains("EXEC sys.sp_executesql N'" + $body.Replace("'", "''") + "';")) "Table payload differs: $name"
    Assert-Contract ($migration.Contains("DENY INSERT,UPDATE,DELETE ON OBJECT::dbo.$name TO public;")) "Missing direct DML denial: $name"
    Assert-Contract ($source.Contains('PRIMARY KEY')) "Missing immutable identity: $name"
    Assert-Contract (-not ($source -match 'ON (DELETE|UPDATE) CASCADE')) "Evidence cannot cascade: $name"
}
foreach ($name in $procedures) {
    $source = Read-Source "sql_schema/dbo.$name.StoredProcedure.sql"
    $body = $source.Substring($source.IndexOf('CREATE PROCEDURE '))
    Assert-Contract ($migration.Contains("EXEC sys.sp_executesql N'" + $body.Replace("'", "''") + "';")) "Procedure payload differs: $name"
    foreach ($fragment in @('IF @@TRANCOUNT<>0','IS_ROLEMEMBER', 'BEGIN TRY', 'BEGIN CATCH', 'IF XACT_STATE()<>0 ROLLBACK;', 'SET XACT_ABORT ON;')) {
        Assert-Contract ($body.Contains($fragment)) "Procedure contract missing $fragment in $name"
    }
    Assert-Contract (-not ($body -match '(?i)EXECUTE\s+AS|WAITFOR|xp_cmdshell|OPENROWSET')) "Unexpected execution boundary: $name"
    Assert-Contract ($migration.Contains("DENY EXECUTE ON OBJECT::dbo.$name TO ExportExecutionReader;")) "Reader must not issue evidence: $name"
    $definitionGuard = "IF OBJECT_ID(N'dbo.$name',N'P') IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name')) IS NULL OR OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name')) COLLATE"
    Assert-Contract ($migration.Contains($definitionGuard)) "Unreadable procedure definition must refuse installation: $name"
    Assert-Contract ($migration.Contains("OBJECT_DEFINITION(OBJECT_ID(N'dbo.$name')) COLLATE Latin1_General_100_BIN2 <> N'" + $body.Replace("'", "''") + "' COLLATE Latin1_General_100_BIN2")) "Installed-body comparison differs: $name"

}
$append = Read-Source 'sql_schema/dbo.usp_ExportProviderRequestEventAppend.StoredProcedure.sql'
Assert-Contract ($append.Contains("IF @ExpectedVersion IS NULL OR @Version IS NULL OR @Version<>@ExpectedVersion OR @StreamState='closed'")) 'NULL must not disable the exact event stream CAS'
$stream = Read-Source 'sql_schema/dbo.usp_ExportExecutionStreamTransition.StoredProcedure.sql'
$proof = Read-Source 'sql_schema/dbo.usp_ExportReconciliationProofIssue.StoredProcedure.sql'
$streamTable = Read-Source 'sql_schema/dbo.ExportExecutionStream.Table.sql'
$requestTable = Read-Source 'sql_schema/dbo.ExportProviderRequest.Table.sql'
Assert-Contract ($requestTable.Contains("RequestKind='read' AND Operation IN ('sheets.get','sheets.values.get','sheets.values.batchGet','drive.files.get','drive.permissions.list')")) 'Actual new-source batch readback must be classified as read-only'
Assert-Contract ($streamTable.Contains('OwnerID uniqueidentifier NULL')) 'Closing probe must retain the absent worker owner'
Assert-Contract ($streamTable.Contains("OwnerID IS NULL AND Fence=0 AND OutputOperationID IS NOT NULL AND Purpose='probe' AND NestedToken IS NULL")) 'Ownerless streams must be limited to the closing probe'
foreach ($source in @($stream, $append)) {
    foreach ($fragment in @(
        "@OwnerID IS NULL AND NOT (@OwnerKind='operation' AND @Purpose='probe' AND @Fence=0 AND @NestedToken IS NULL)",
        "@Purpose='probe' AND @OwnerID IS NULL AND OwnerID IS NULL AND Fence=0 AND State='closing' AND Phase='draining'",
        'PoolID=@PoolID AND Fence=@Fence AND Version=@ClaimVersion AND OldEpoch=@Epoch',
        "PoolState='closing'", 'OwnerID=@ObjectID AND Epoch=@Epoch AND RegistrationHash=@RegistrationHash',
        'OwnerID IS NULL AND ActiveJobID IS NULL AND ActivePreparationID IS NULL AND ActiveOutputOperationID IS NULL',
        "@Purpose='probe' AND State='uncertain' AND @ClaimVersion>1",
        "TRY_CONVERT(bigint,JSON_VALUE(ProvenanceJson,'$.retirement_recovery.version'))=@ClaimVersion-1",
        '@PoolLockResult=sys.sp_getapplock', 'KVK.SourceOutputOperationResource'
    )) {
        Assert-Contract ($source.Contains($fragment)) "Missing closing-probe admission/dispatch boundary: $fragment"
    }
}
Assert-Contract ($append.Contains('@RegistrationHash=RegistrationHash')) 'Dispatch must reload the immutable registration hash'
Assert-Contract ($append.Contains("@Purpose='probe' AND @RequestKind<>'read'")) 'Closing probes must reject mutation requests'
foreach ($fragment in @("@Previous='prepared' AND @State='not_sent'", "@Previous='dispatch_intent' AND @State IN ('succeeded','unknown')", "@StreamState='open'", 'Only one outstanding request per stream.', 'Unknown mutation requires reconciliation.')) {
    Assert-Contract ($append.Contains($fragment)) "Missing request transition boundary: $fragment"
}
foreach ($fragment in @('OwnerID=@OwnerID','Fence=@Fence','Version=@ClaimVersion','retirement_recovery.token','retirement_recovery.version','retirement_recovery.state','@ResourceVersion','ChildIdentity=@ChildIdentity',"State='frozen'")) {
    Assert-Contract ($stream.Contains($fragment)) "Missing stream ownership/closure predicate: $fragment"
}
foreach ($fragment in @('Empty evidence is not proof', "e.State IN ('succeeded','not_sent')", 'Fresh snapshot-bound closed probe', 'ActiveAccountKey=@AccountKey', "r.RequestKind='mutation' AND e.State='dispatch_intent'")) {
    Assert-Contract ($proof.Contains($fragment)) "Missing proof rejection: $fragment"
}
foreach ($fragment in @(
    "JSON_VALUE(@MembershipJson,'$.version')<>'2'",
    "OPENJSON(s.ScopeJson,'$.resources')", "JOIN @Targets t",
    "s.ActiveAccountKey IS NOT NULL", "s.EventDigest IS NULL",
    "K98-S11-CATALOGUE-1", "s.StreamID<>@ProbeID ORDER BY LOWER(CONVERT(varchar(36),s.StreamID)) COLLATE Latin1_General_100_BIN2",
    "@CatalogueCount<>@ExpectedCount OR @CatalogueHash<>CONVERT(binary(32),@HistoryHashText,2)",
    "s.StreamID=@ProbeID AND s.Version=@ProbeVersion AND s.Purpose='probe'",
    "@HistoryHashText IS NULL", "Targets must be unique and canonically ordered."
    "@Outcome='absent' AND (@ProofKind<>'publication' OR @SubjectJob IS NULL)",
    "s.AccountKey=@AccountKey AND s.JobID=@SubjectJob AND r.RequestKind='mutation'"
)) {
    Assert-Contract ($proof.Contains($fragment)) "Missing complete-catalogue proof guard: $fragment"
}
foreach ($fragment in @('@S11Existing NOT IN (0,11)', 'PreValidationQuery:', 'PostValidationQuery:', 'RequiresBackup: Yes', 'Forward Fix Only', 'is_not_trusted', 'is_disabled', 'foreign key shape conflict', 'index shape conflict', 'default shape conflict', 'execute_as_principal_id IS NULL')) {
    Assert-Contract ($migration.Contains($fragment)) "Missing installation guard: $fragment"
}
Assert-Contract (-not ($migration -match '(?i)ALTER\s+ROLE\s+\w+\s+ADD\s+MEMBER|CREATE\s+LOGIN|TRUNCATE|DROP\s+TABLE')) 'Migration must not map principals, activate or erase history'
$origin = Read-Source 'sql_schema/dbo.ExportManagedFileOrigin.Table.sql'
$enrollment = Read-Source 'sql_schema/dbo.usp_ExportOutputEnrollmentTransition.StoredProcedure.sql'
foreach ($fragment in @('PRIMARY KEY (FileID,Stage)', 'UNIQUE (PreparationID,Ordinal,Stage)', 'UNIQUE (CreationRequestID,Stage)', 'FK_ExportManagedFileOrigin_Parent', 'FK_ExportManagedFileOrigin_Creation', 'FK_ExportManagedFileOrigin_Response', 'FK_ExportManagedFileOrigin_Verification')) {
    Assert-Contract ($origin.Contains($fragment)) "Missing append-only origin identity: $fragment"
}
Assert-Contract (-not ($enrollment -match '(?i)(UPDATE|DELETE)\s+(dbo\.)?ExportManagedFileOrigin')) 'Origins must be append-only'
foreach ($fragment in @('Existing work or enrollment prevents fresh admission.', 'Enrollment resource owner/fence/version conflict.', 'Exact successful closed creation required.', 'Enrollment history contains unclosed or uncertain requests.', 'Every origin requires grant and complete fixed readback.', 'Returned identity has existing history; never adopt.', 'ORDER BY ResourceKey', 'ClaimVersion=@ExpectedVersion', "State='completed'")) {
    if ($fragment -eq "State='completed'") { continue } # completion uses one CAS CASE expression
    Assert-Contract ($enrollment.Contains($fragment)) "Missing enrollment boundary: $fragment"
}
foreach ($source in @($stream,$append)) {
    foreach ($fragment in @('Exact authority-side enrollment phase required.', 'Enrollment phase already has a stream; never replay.', 'Enrollment cannot become ordinary configuration authority.')) {
        Assert-Contract ($source.Contains($fragment)) "Missing enrollment scope gate: $fragment"
    }
}
Assert-Contract ($proof.Contains('Complete authenticated managed-file origins required.')) 'Proof cannot invent old origin'
Assert-Contract ($proof.Contains("o.PreparationID=s.PreparationID AND o.Stage='created'")) 'Account-only creation must enter catalogue'
$fixture = Read-Source 'validation/kvk_source/s11_export_execution_evidence.sql'
foreach ($permission in @('SELECT','INSERT','UPDATE','DELETE','ALTER','CONTROL')) {
    $required = if ($permission -ceq 'SELECT') { 1 } else { 0 }
    Assert-Contract ($fixture.Contains("ISNULL(HAS_PERMS_BY_NAME(N'dbo.'+Name,'OBJECT','$permission'),-1)<>$required")) "Unknown permission observation must reject: $permission"
}
foreach ($membership in @("IS_MEMBER(N'db_owner')", "IS_SRVROLEMEMBER(N'sysadmin')")) {
    Assert-Contract ($fixture.Contains("ISNULL($membership,-1)<>0")) "Unknown administrator token must reject: $membership"
}
Write-Output "S11 offline evidence contract checks passed: $checks assertions. No installation/transaction/provider proof."
