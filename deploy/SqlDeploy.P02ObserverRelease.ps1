# Explicit observer successor over D4. Source pins are independent of live SQL.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Read-K98ObserverProfile($Profile,[string]$Path) {
    Assert-K98ModuleFields $Profile @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','requires','script','protocol_sha256','legacy_source_sha256','predecessor_bodies_utf16le_lf','source_files','bootstrap_generation','checks')
    if($Profile.version -ne 1 -or $Profile.profile -cne 'p02_catalogue_observer_v1' -or $Profile.migration_id -cne '20261120_001_p02_catalogue_observer'){throw 'Exact observer profile identity required'}
    if((Get-K98ModuleHash ([IO.File]::ReadAllBytes($Path))) -cne 'cd3bcb8c1f7303b8b45d5dc2b3d118aad70002f684ae847ffaf400c056bc1692'){throw 'Fixed reviewed observer profile bytes required'}
    $texts=@{}
    foreach($phase in @('script','before','after')) {
        $item=if($phase -ceq 'script'){$Profile.script}else{$Profile.checks.$phase}
        Assert-K98ModuleFields $item @('file','sha256')
        $file=Join-Path (Split-Path -Parent $Path) $item.file
        $info=Get-Item -LiteralPath $file -Force
        if($info.PSIsContainer -or ($info.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $info.Length -gt 512KB){throw 'Bounded ordinary observer SQL file required'}
        $raw=[IO.File]::ReadAllBytes($file)
        if((Get-K98ModuleHash $raw) -cne $item.sha256){throw ('Observer SQL bytes changed: '+$phase)}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($raw)
        if($text -match '(?im)^\s*(GO(?:\s|$)|USE\s|:)'){throw 'Observer requires fixed single database batches'}
        $texts[$phase]=$text
    }
    return @{Profile=$Profile;Commands=@($texts.script);BeforeCheck=$texts.before;AfterCheck=$texts.after}
}

function Assert-K98ObserverImages($Connection,$Transaction,$Loaded,[bool]$After) {
    $sql=if($After){$Loaded.AfterCheck}else{$Loaded.BeforeCheck}
    $null=Invoke-K98ModuleQuery $Connection $Transaction $sql
}

# Catalogue timestamps are SQL datetime. Preserve the millisecond rendering
# used by the authenticated ODBC observation, not datetime2 binary expansion.
function ConvertTo-K98ObserverStamp($Stamp) {
    if($Stamp -isnot [datetime]){throw 'Typed SQL catalogue timestamp required'}
    # ODBC renders SQL datetime to its nearest millisecond. SqlClient can expose
    # the underlying fractional tick. Canonicalize that transport difference,
    # with integer arithmetic and carry into the next second when necessary.
    $remainder=$Stamp.Ticks % 10000
    $ticks=$Stamp.Ticks-$remainder
    if($remainder -ge 5000){$ticks+=10000}
    return ([datetime]::new($ticks)).ToString('yyyy-MM-ddTHH:mm:ss.ffffff',[Globalization.CultureInfo]::InvariantCulture)
}

function Get-K98ObserverIncarnation($Connection,$Transaction,$Loaded,[switch]$Bootstrap) {
    $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')) AS server,
 DB_NAME() AS [database],DB_ID() AS database_id,s.object_id AS sequence_object_id,
 s.create_date AS sequence_created,
 s.modify_date AS sequence_modified,
 CONVERT(bigint,s.current_value) AS generation
FROM sys.sequences s WHERE s.object_id=OBJECT_ID(N'dbo.P02ObservationGeneration');
'@
    if($rows.Count -ne 1){throw 'Complete observer incarnation read required'}
    $row=$rows[0]
    $row.sequence_created=ConvertTo-K98ObserverStamp $row.sequence_created
    $row.sequence_modified=ConvertTo-K98ObserverStamp $row.sequence_modified
    if($row.server -ine 'MINI_AMD' -or $row.database -cne 'ROK_TRACKER' -or $row.database_id -le 0 -or $row.sequence_object_id -le 0 -or $row.sequence_created -cne $row.sequence_modified -or $row.sequence_created -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}$' -or $row.generation -lt 1 -or $row.generation -ge [long]::MaxValue){throw 'Exact unaltered observer incarnation required'}
    if($Bootstrap -and $row.generation -ne 1){throw 'Observer bootstrap must be acknowledged inside the install transaction'}
    return [pscustomobject][ordered]@{version=1;protocol_sha256=$Loaded.Profile.protocol_sha256;server=$row.server;database=$row.database;database_id=[int]$row.database_id;sequence_object_id=[int]$row.sequence_object_id;sequence_created=$row.sequence_created;sequence_modified=$row.sequence_modified;bootstrap_generation=1}
}

function Assert-K98ObserverCommittedBinding($Connection,$Loaded,$Binding,$Transaction=$null) {
    Assert-K98ModuleFields $Binding @('migration_id','profile_sha256','sql_commit','release_id','observation_installation')
    $current=Get-K98ObserverIncarnation $Connection $Transaction $Loaded
    $recorded=$Binding.observation_installation
    Assert-K98ModuleFields $recorded @('version','protocol_sha256','server','database','database_id','sequence_object_id','sequence_created','sequence_modified','bootstrap_generation')
    foreach($name in $current.PSObject.Properties.Name) {
        # Exact JSON types avoid coercing strings into receipt integers.
        $left=$current.$name|ConvertTo-Json -Compress
        $right=$recorded.$name|ConvertTo-Json -Compress
        if($left -cne $right){throw ('Committed observer incarnation differs: '+$name+'; preserve the receipt and do not reinstall or adopt live identity.')}
    }
    $Loaded.ObserverInstallation=$current
}
