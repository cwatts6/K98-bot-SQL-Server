# Fixed P02 Phase 1 release. Profile/script bytes are independently qualified.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Read-K98Phase1Profile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires','script','images')
    if($Profile.version -ne 1 -or $Profile.profile -cne 'p02_phase1_v1' -or $Profile.migration_id -cne '20261109_001_p02_phase1_sql_exports') {throw 'Exact Phase 1 profile identity required'}
    if((Get-K98ModuleHash ([IO.File]::ReadAllBytes($Path))) -cne '520b58c1b25d80bd28f32324d99b5fede0d6191ddab93ac93469ed5c1f6e4041'){throw 'Fixed qualified Phase 1 profile bytes required'}
    Assert-K98ModuleFields $Profile.script @('file','sha256')
    if($Profile.script.file -cne '20261109_001_p02_phase1_sql_exports.sql' -or $Profile.script.sha256 -cne '6cc6cb23b0af1123d7c86b4e47c2485880aee0cbfc097b2b5306a746da8a23fb'){throw 'Exact Phase 1 script identity required'}
    $file=Join-Path (Split-Path -Parent $Path) $Profile.script.file
    $item=Get-Item -LiteralPath $file -Force
    if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 2MB){throw 'Bounded ordinary Phase 1 script required'}
    $raw=[IO.File]::ReadAllBytes($file)
    if((Get-K98ModuleHash $raw) -cne $Profile.script.sha256){throw 'Phase 1 script bytes changed'}
    $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw)
    if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'Phase 1 requires its fixed single database batch'}
    if(@($Profile.images).Count -ne 57 -or @($Profile.requires).Count -ne 5){throw 'Complete Phase 1 object and predecessor inventory required'}
    return @{Profile=$Profile;Commands=@($text)}
}

function Assert-K98Phase1Images($Connection,$Transaction,$Loaded,[bool]$After) {
    . "$PSScriptRoot\SqlDeploy.RecoveryRelease.ps1"
    foreach($item in $Loaded.Profile.images) {
        $expected=if($After){$item.after}else{$item.before}
        $actual=Get-K98RecoveryImage $Connection $Transaction $item.name
        if($actual -cne $expected){throw ('Phase 1 '+$(if($After){'postimage'}else{'preimage'})+' differs: '+$item.name+'; preserve evidence and inspect, do not adopt observed hashes.')}
    }
}

function Get-K98Phase1SnapshotState($Connection) {
    $rows=Invoke-K98ModuleQuery $Connection $null @'
SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server_name,
 DB_NAME() AS database_name,snapshot_isolation_state,is_read_committed_snapshot_on,
 is_read_only,user_access FROM sys.databases WHERE database_id=DB_ID();
'@
    if($rows.Count -ne 1){throw 'Exact Phase 1 database state required'}
    $state=$rows[0]
    if($state.server_name -cne 'MINI_AMD' -or $state.database_name -cne 'ROK_TRACKER' -or $state.is_read_committed_snapshot_on -or $state.is_read_only -or $state.user_access -ne 0){throw 'Exact Phase 1 target and unchanged read-committed mode required'}
    if($state.snapshot_isolation_state -notin @(0,1)){throw 'Snapshot setting is transitioning; preserve same-release evidence and inspect status, do not repeat ALTER'}
    return [int]$state.snapshot_isolation_state
}

function Enable-K98Phase1Snapshot($Connection) {
    # Invoked only after the coordinator has drained producers, authenticated
    # exact preimages and recorded this release's Started attempt. This setting
    # is outside the schema transaction and is reported separately on failure.
    $state=Get-K98Phase1SnapshotState $Connection
    if($state -eq 0){
        $null=Invoke-K98ModuleQuery $Connection $null 'ALTER DATABASE CURRENT SET ALLOW_SNAPSHOT_ISOLATION ON;'
    }
    if((Get-K98Phase1SnapshotState $Connection) -ne 1){throw 'Snapshot enablement did not reach the required stable state'}
}

function Assert-K98Phase1Resources($Connection,$Transaction) {
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM sys.dm_db_log_space_usage WHERE used_log_space_in_percent<70)
 THROW 52980,'Phase 1 log usage reached the unchanged 70 percent ceiling.',1;
IF NOT EXISTS(SELECT 1 FROM tempdb.sys.dm_db_file_space_usage HAVING SUM(CONVERT(bigint,version_store_reserved_page_count))*8<524288)
 THROW 52980,'Phase 1 version store reached the unchanged 512 MiB ceiling.',1;
IF EXISTS(SELECT 1 FROM sys.master_files f OUTER APPLY sys.dm_os_volume_stats(f.database_id,f.file_id) v
 WHERE f.database_id IN(DB_ID(),2) AND (v.available_bytes IS NULL OR v.available_bytes<8589934592))
 THROW 52980,'Phase 1 data/log or temporary volume would cross the unchanged 8 GiB reserve.',1;
IF NOT EXISTS(SELECT 1 FROM sys.master_files f OUTER APPLY sys.dm_os_volume_stats(f.database_id,f.file_id) v
 WHERE f.database_id=DB_ID() AND v.available_bytes>=8589934592)
 OR NOT EXISTS(SELECT 1 FROM sys.master_files f OUTER APPLY sys.dm_os_volume_stats(f.database_id,f.file_id) v
 WHERE f.database_id=2 AND v.available_bytes>=8589934592)
 THROW 52980,'Complete Phase 1 volume capacity evidence required.',1;
'@
}
