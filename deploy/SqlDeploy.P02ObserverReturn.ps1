# Two fixed, operator-controlled transitions. Never reinstall the observer.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\SqlDeploy.P02ObserverRelease.ps1"

function Read-K98ObserverReturnProfile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','action','database_collation','tempdb_collation','compatibility_level','requires','protocol_sha256','script','checks')
    $pins=@{
        '20261123_001_p02_observer_return'=@('return','c7d24d3e25c3a3f62fba6484e993c26a19fcb8cefe1d55a607027907beced71c')
        '20261123_002_p02_observer_reupgrade'=@('reupgrade','4fb8a16cfd8a09420a4d8d11a40a1eb36496fa611e4c16bc6d290b7973f3d577')
    }
    if($Profile.version -ne 1 -or $Profile.profile -cne 'p02_observer_return_v1' -or -not $pins.ContainsKey($Profile.migration_id)){throw 'Exact P02 return pair required'}
    $pin=$pins[$Profile.migration_id]
    if($Profile.action -cne $pin[0] -or (Get-K98ModuleHash ([IO.File]::ReadAllBytes($Path))) -cne $pin[1]){throw 'Fixed reviewed P02 return profile required'}
    Assert-K98ModuleFields $Profile.checks @('before','after')
    $texts=@{}
    foreach($phase in @('script','before','after')) {
        $item=if($phase -ceq 'script'){$Profile.script}else{$Profile.checks.$phase}
        Assert-K98ModuleFields $item @('file','sha256')
        $name=$Profile.migration_id+$(if($phase -ceq 'script'){'.sql'}else{'.'+$phase+'.sql'})
        if($item.file -cne $name -or $item.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Exact return SQL member required'}
        $file=Join-Path (Split-Path -Parent $Path) $name
        $info=Get-Item -LiteralPath $file -Force
        if($info.PSIsContainer -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $info.Length -gt 512KB){throw 'Bounded ordinary return SQL file required'}
        $raw=[IO.File]::ReadAllBytes($file)
        if((Get-K98ModuleHash $raw) -cne $item.sha256){throw ('Return SQL bytes changed: '+$phase)}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw)
        if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'Return requires fixed single database batches'}
        $texts[$phase]=$text
    }
    return @{Profile=$Profile;Commands=@($texts.script);BeforeCheck=$texts.before;AfterCheck=$texts.after}
}

function Get-K98OriginalObserverBinding($Connection,$Transaction,$Loaded) {
    $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT m.Status AS migration_status,m.ChecksumSha256 AS profile_sha256,
 m.GitCommit AS sql_commit,m.DeploymentId AS deployment_id,
 d.Status AS deployment_status,d.GitCommit AS deployment_commit,
 d.BranchName AS deployment_profile,d.DatabaseName AS deployment_database,
 d.ErrorMessage AS binding
FROM dbo.SchemaMigrationHistory m JOIN dbo.DeploymentRunHistory d ON d.DeploymentId=m.DeploymentId
WHERE m.MigrationId=N'20261120_001_p02_catalogue_observer';
'@
    if($rows.Count -ne 1){throw 'Exact original observer history required; no adoption or reinstall'}
    $r=$rows[0]
    if($r.migration_status -cne 'Applied' -or $r.profile_sha256 -cne 'cd3bcb8c1f7303b8b45d5dc2b3d118aad70002f684ae847ffaf400c056bc1692' -or $r.sql_commit -cnotmatch '^[a-f0-9]{40}$' -or $r.deployment_status -cne 'Succeeded' -or $r.deployment_commit -cne $r.sql_commit -or $r.deployment_profile -cne 'p02_catalogue_observer_v1' -or $r.deployment_database -cne 'ROK_TRACKER'){throw 'Original observer commit/attempt differs; preserve history'}
    $binding=ConvertFrom-K98ModuleJson $r.binding
    Assert-K98ModuleFields $binding @('migration_id','profile_sha256','sql_commit','release_id','observation_installation')
    if($binding.migration_id -cne '20261120_001_p02_catalogue_observer' -or $binding.profile_sha256 -cne $r.profile_sha256 -or $binding.sql_commit -cne $r.sql_commit -or $binding.release_id -cnotmatch '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'){throw 'Original observer release binding differs'}
    Assert-K98ObserverCommittedBinding $Connection $Loaded $binding $Transaction
    return $Loaded.ObserverInstallation
}

function Assert-K98ObserverReturnImages($Connection,$Transaction,$Loaded,[bool]$After) {
    $null=Get-K98OriginalObserverBinding $Connection $Transaction $Loaded
    $sql=if($After){$Loaded.AfterCheck}else{$Loaded.BeforeCheck}
    $null=Invoke-K98ModuleQuery $Connection $Transaction $sql
}

function Assert-K98ObserverReturnBinding($Connection,$Loaded,$Binding) {
    $null=Get-K98OriginalObserverBinding $Connection $null $Loaded
    # The return/reupgrade receipt must retain the original incarnation, too.
    # A valid original row cannot bless a replacement in a new stage receipt.
    Assert-K98ObserverCommittedBinding $Connection $Loaded $Binding
}
