# Fixed P02 D4 successor. Historical Phase 1 contracts remain immutable.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Read-K98D4Profile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires','script','images')
    if($Profile.version -ne 1 -or $Profile.profile -cne 'p02_d4_v1' -or $Profile.migration_id -cne '20261111_001_p02_d4_combined'){throw 'Exact D4 profile identity required'}
    if((Get-K98ModuleHash ([IO.File]::ReadAllBytes($Path))) -cne '57944777e50b7dc9200220cfcc2ce767edb22a2e0972e02bc2cd6f04e23e8171'){throw 'Fixed qualified D4 profile bytes required'}
    Assert-K98ModuleFields $Profile.script @('file','sha256')
    if($Profile.script.file -cne '20261111_001_p02_d4_combined.sql' -or $Profile.script.sha256 -cne '8c0c99d92c14cac6da6e22076a5620927bac4c8af3deaa50950d66062381a8dc'){throw 'Exact D4 script identity required'}
    $file=Join-Path (Split-Path -Parent $Path) $Profile.script.file
    $item=Get-Item -LiteralPath $file -Force
    if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 512KB){throw 'Bounded ordinary D4 script required'}
    $raw=[IO.File]::ReadAllBytes($file)
    if((Get-K98ModuleHash $raw) -cne $Profile.script.sha256){throw 'D4 script bytes changed'}
    $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw)
    if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'D4 requires its fixed single database batch'}
    if(@($Profile.images).Count -ne 30 -or @($Profile.requires).Count -ne 6){throw 'Complete D4 object and predecessor inventory required'}
    return @{Profile=$Profile;Commands=@($text)}
}

function Assert-K98D4Images($Connection,$Transaction,$Loaded,[bool]$After) {
    . "$PSScriptRoot\SqlDeploy.RecoveryRelease.ps1"
    foreach($item in $Loaded.Profile.images) {
        $expected=if($After){$item.after}else{$item.before}
        $actual=Get-K98RecoveryImage $Connection $Transaction $item.name
        if($actual -cne $expected){throw ('D4 '+$(if($After){'postimage'}else{'preimage'})+' differs: '+$item.name+'; preserve evidence and inspect, do not adopt observed hashes.')}
    }
}

function Assert-K98D4Dependencies($Connection,$Transaction=$null) {
    $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,
 DB_NAME() AS database_name,snapshot_isolation_state,is_read_committed_snapshot_on,
 is_read_only,user_access FROM sys.databases WHERE database_id=DB_ID();
'@
    if($rows.Count -ne 1){throw 'Exact D4 database state required'}
    $state=$rows[0]
    if($state.server_name -ine 'MINI_AMD' -or $state.database_name -cne 'ROK_TRACKER' -or $state.snapshot_isolation_state -ne 1 -or $state.is_read_committed_snapshot_on -or $state.is_read_only -or $state.user_access -ne 0){throw 'D4 requires the exact installed target, stable snapshot mode and unchanged RCSI; no setting change is authorized'}
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM sys.sequences s JOIN sys.schemas sc ON sc.schema_id=s.schema_id
 WHERE sc.name=N'dbo' AND s.name=N'KS4_UNO_SEQ' AND TYPE_NAME(s.user_type_id)=N'int'
 AND CONVERT(bigint,s.start_value)=130489 AND CONVERT(bigint,s.increment)=1
 AND CONVERT(bigint,s.minimum_value)=-2147483648 AND CONVERT(bigint,s.maximum_value)=2147483647
 AND s.is_cycling=0 AND s.is_cached=0 AND s.cache_size IS NULL AND s.is_exhausted=0
 AND USER_NAME(COALESCE(s.principal_id,sc.principal_id))=N'dbo')
 THROW 52981,'Exact existing sequence structure and usable state required; do not recreate or reset.',1;
DECLARE @wrapper int=(SELECT p.object_id FROM msdb.sys.procedures p JOIN msdb.sys.schemas s ON s.schema_id=p.schema_id WHERE s.name=N'dbo' AND p.name=N'usp_start_rok_tracker_log_backup');
IF @wrapper IS NULL OR NOT EXISTS(SELECT 1 FROM msdb.sys.sql_modules m JOIN msdb.sys.objects o ON o.object_id=m.object_id JOIN msdb.sys.schemas s ON s.schema_id=o.schema_id
 WHERE m.object_id=@wrapper AND m.execute_as_principal_id=-2 AND m.uses_ansi_nulls=1 AND m.uses_quoted_identifier=1
 AND COALESCE((SELECT name FROM msdb.sys.database_principals WHERE principal_id=o.principal_id),(SELECT name FROM msdb.sys.database_principals WHERE principal_id=s.principal_id))=N'dbo'
 AND CONVERT(varchar(64),HASHBYTES('SHA2_256',REPLACE(m.definition,NCHAR(13)+NCHAR(10),NCHAR(10))),2)='CFB329191180C86C1B5A2C79B4F0E3F79D4E90A3133950D6D01A5FEE64CFBF5A')
 THROW 52981,'Exact installed fixed backup wrapper required; no guessed replacement or dispatch.',1;
IF EXISTS(SELECT 1 FROM msdb.sys.crypt_properties WHERE class=1 AND major_id=@wrapper)
 THROW 52981,'Backup wrapper signature state differs.',1;
DECLARE @rights nvarchar(max)=(SELECT u.name AS grantee,g.name AS grantor,p.permission_name,p.state_desc,p.minor_id
 FROM msdb.sys.database_permissions p JOIN msdb.sys.database_principals u ON u.principal_id=p.grantee_principal_id
 JOIN msdb.sys.database_principals g ON g.principal_id=p.grantor_principal_id
 WHERE p.class=1 AND p.major_id=@wrapper
 ORDER BY u.name COLLATE Latin1_General_100_BIN2,g.name COLLATE Latin1_General_100_BIN2,p.permission_name COLLATE Latin1_General_100_BIN2,p.state_desc COLLATE Latin1_General_100_BIN2,p.minor_id FOR JSON PATH);
IF CONVERT(varchar(64),HASHBYTES('SHA2_256',@rights),2)<>'3F9823AC3F9CF8983F67359B0D13DF79BAD1A8F5BFD0A4D5A64D0BF29D0F2BA0'
 THROW 52981,'Backup wrapper object permissions differ; no grant changes are authorized.',1;
IF ISNULL((SELECT IS_SRVROLEMEMBER(N'sysadmin',SUSER_SNAME(owner_sid)) FROM sys.databases WHERE name=N'msdb'),0)<>1
 OR (SELECT COUNT(*) FROM msdb.dbo.sysjobs WHERE enabled=1 AND CONVERT(varchar(64),HASHBYTES('SHA2_256',UPPER(CONVERT(nvarchar(36),job_id))),2)='DD0CBB684C3CEA798026CF11861FFA27CA76AA6447BAD43789962E6FDC90E6F0')<>1
 THROW 52981,'Fixed enabled backup job and owner capability required; do not invoke or alter the job.',1;
'@
}

function Assert-K98D4Resources($Connection,$Transaction=$null) {
    . "$PSScriptRoot\SqlDeploy.Phase1Release.ps1"
    Assert-K98Phase1Resources $Connection $Transaction
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM sys.dm_os_sys_memory WHERE available_physical_memory_kb>=8388608)
 THROW 52981,'D4 memory would cross the unchanged 8 GiB reserve.',1;
'@
}
