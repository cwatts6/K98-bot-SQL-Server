param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $RepositoryRoot 'deploy/StatsImportOutcome.Source.ps1')
function Hash-Definition([string]$Value) {
    $value=$Value.Replace("`r`n","`n").Trim([char[]]" `t`r`n")
    $value=[regex]::Replace($value,'^(ALTER|CREATE OR ALTER)\b','CREATE')
    $hash=[Security.Cryptography.SHA256]::Create()
    try {return ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::Unicode.GetBytes($value)))).Replace('-','').ToLowerInvariant()} finally {$hash.Dispose()}
}
$oldPath=Join-Path $RepositoryRoot 'migrations/20261010_001_stats_import_outcomes_collation.sql'
if((Get-FileHash -LiteralPath $oldPath).Hash.ToLowerInvariant() -cne 'e423e79fd13234b91b62336ab8e34ff2b018b2bffcdfb3cd53dec1a9342ef315'){throw 'Historical migration changed'}
$current=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql'))
$source=Get-S11PreOutcomeSource $current
$start=[regex]::Match($source,'(?m)^(ALTER PROCEDURE|CREATE OR ALTER PROCEDURE)').Index
$source=$source.Substring($start).Trim()
$legacy=[Text.Encoding]::GetEncoding(1252).GetString([Text.Encoding]::UTF8.GetBytes($source))
if((Hash-Definition $source) -cne 'd89d8cdd46020f3a464baf5cb0cbc1f30fb5734efe36316865dac88cabd24b68'){throw 'Repository predecessor differs'}
if((Hash-Definition $legacy) -cne 'cbe4077f8f1f2f92bccede963f19919665f4fcefe63def90fd834bf92a723cc9'){throw 'Independently derived legacy spelling differs'}
$before=$source -split "`n";$after=$legacy -split "`n";$changed=0
for($i=0;$i -lt $before.Count;$i++) {
    if($before[$i] -ceq $after[$i]){continue}
    $changed++
    $a=$before[$i].IndexOf('--');$b=$after[$i].IndexOf('--')
    if($a -lt 0 -or $a -ne $b -or $before[$i].Substring(0,$a) -cne $after[$i].Substring(0,$b)){throw 'Legacy spelling changes SQL outside comments'}
}
if($changed -ne 11){throw 'Expected eleven exact comment differences'}
$old=[IO.File]::ReadAllText($oldPath)
$new=[IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261010_002_stats_import_outcomes_encoding.sql'))
$pattern="EXEC sys\.sp_executesql N'(?<body>(?:[^']|'')*)';"
$oldBodies=[regex]::Matches($old,$pattern,[Text.RegularExpressions.RegexOptions]::Singleline)
$newBodies=[regex]::Matches($new,$pattern,[Text.RegularExpressions.RegexOptions]::Singleline)
if($oldBodies.Count -ne 2 -or $newBodies.Count -ne 2){throw 'Expected exactly two module bodies'}
for($i=0;$i -lt 2;$i++){if($oldBodies[$i].Value -cne $newBodies[$i].Value){throw 'Reviewed installed module body changed'}}
foreach($hash in @('d89d8cdd46020f3a464baf5cb0cbc1f30fb5734efe36316865dac88cabd24b68','cbe4077f8f1f2f92bccede963f19919665f4fcefe63def90fd834bf92a723cc9','4a5640dbdf811d645ba9ed83062f08408f5d02e6c9c2338585042b031af080bc')){if(-not $new.Contains('0x'+$hash)){throw 'Missing exact reviewed definition hash'}}
if($new.IndexOf('Installed UPDATE_ALL2 source differs') -gt $new.LastIndexOf('    COMMIT;')){throw 'Postimage check must precede commit'}
Write-Host 'PASS: exact repository/legacy predecessor hashes, eleven comment-only differences, unchanged module bodies, postimage checks.'
