# Exact forward correction; original bootstrap and all business records remain intact.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\SqlDeploy.P02ObserverReturn.ps1"

function Read-K98ObserverOptionsProfile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires','protocol_sha256','script','checks')
    $profiles=@{
        '20261125_001_p02_observer_xml_options'='ebf2a575c20c439a8f63496171c0602a649c0e09ddb7c05fa6b8abef66017bfe'
        '20261125_002_p02_observer_options_marker'='0376bc6e8b13e87fb67ff97976c91fbcc1d644ca8e4fe91c068a7b050e84bf97'
    }
    if($Profile.version -ne 1 -or $Profile.profile -cne 'p02_observer_options_v1' -or
       -not $profiles.ContainsKey([string]$Profile.migration_id) -or
       (Get-K98ModuleHash ([IO.File]::ReadAllBytes($Path))) -cne $profiles[[string]$Profile.migration_id]){throw 'Fixed reviewed observer options profile required'}
    Assert-K98ModuleFields $Profile.checks @('before','after')
    $texts=@{}
    foreach($phase in @('script','before','after')) {
        $item=if($phase -ceq 'script'){$Profile.script}else{$Profile.checks.$phase}
        Assert-K98ModuleFields $item @('file','sha256')
        $name=$Profile.migration_id+$(if($phase -ceq 'script'){'.sql'}else{'.'+$phase+'.sql'})
        if($item.file -cne $name -or $item.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'Exact options SQL member required'}
        $file=Join-Path (Split-Path -Parent $Path) $name
        $info=Get-Item -LiteralPath $file -Force
        if($info.PSIsContainer -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $info.Length -gt 512KB){throw 'Bounded ordinary options SQL file required'}
        $raw=[IO.File]::ReadAllBytes($file)
        if((Get-K98ModuleHash $raw) -cne $item.sha256){throw ('Options SQL bytes changed: '+$phase)}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw)
        if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'Options correction requires fixed single database batches'}
        $texts[$phase]=$text
    }
    return @{Profile=$Profile;Commands=@($texts.script);BeforeCheck=$texts.before;AfterCheck=$texts.after}
}
function Get-K98ObserverOptionsIncarnation($Connection,$Transaction,$Loaded) {
    # Validate the immutable original ledger with its original protocol first.
    $original=@{Profile=[pscustomobject]@{protocol_sha256='73be803fe432907cccee0ed86fe593e733b6d682959f4e526f6d7ec47d7a53cc'}}
    $incarnation=Get-K98OriginalObserverBinding $Connection $Transaction $original
    # This changes only the reviewed protocol, never sequence identity or bootstrap.
    $incarnation.protocol_sha256=$Loaded.Profile.protocol_sha256
    $Loaded.ObserverInstallation=$incarnation
    return $incarnation
}
function Assert-K98ObserverOptionsImages($Connection,$Transaction,$Loaded,[bool]$After) {
    $null=Get-K98ObserverOptionsIncarnation $Connection $Transaction $Loaded
    $sql=if($After){$Loaded.AfterCheck}else{$Loaded.BeforeCheck}
    $null=Invoke-K98ModuleQuery $Connection $Transaction $sql
}
function Assert-K98ObserverOptionsBinding($Connection,$Loaded,$Binding) {
    $null=Get-K98ObserverOptionsIncarnation $Connection $null $Loaded
    Assert-K98ObserverCommittedBinding $Connection $Loaded $Binding
}
