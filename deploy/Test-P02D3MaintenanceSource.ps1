param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline source custody only. This is not an installed permission/source
# allowlist or an installer; D4 must qualify the coordinated final release.
$expected=@{
    'sql_schema/dbo.MaintenanceWork.Table.sql'='cbfd167a825c5903b49ef8882bc990d351e7e67f6f94f04ecb71c5b9323fe200'
    'sql_schema/dbo.usp_MaintenanceDue.StoredProcedure.sql'='c0f9cd9fedcefd7a031a8c7541fe10d7c4165cdc6fb5397bc3c670743b0cd2dc'
    'sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql'='b5000239fb1289b45543984b0682ace13c8f52947aa3ceb7dec140d0c02240cd'
    'sql_schema/dbo.usp_RunMaintenance.StoredProcedure.sql'='d1a534de14b621dba5c0df1c573eb8d3c44e29c143b519912f9ec6f99368fe8e'
    'sql_schema/dbo.usp_update_stats.StoredProcedure.sql'='a38bc052259aef2d64ba9217618532dd29e4f731ffc48f914bff45a7ae3196de'
}
foreach($path in $expected.Keys) {
    $text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")
    $hash=[Security.Cryptography.SHA256]::Create()
    try { $actual=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if($actual -cne $expected[$path]){throw "Unreviewed D3 maintenance source: $path"}
}
Write-Output 'PASS: five fixed D3b source candidates; no SQL connection or deployment authority.'
