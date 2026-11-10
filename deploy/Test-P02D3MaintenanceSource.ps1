param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline source custody only. This is not an installed permission/source
# allowlist or an installer; D4 must qualify the coordinated final release.
$expected=@{
    'sql_schema/dbo.MaintenanceWork.Table.sql'='5415c834690180f5fcca45e1667de916c5b33671d9037bd55f03109c7993a4d3'
    'sql_schema/dbo.usp_MaintenanceDue.StoredProcedure.sql'='512f44bbe2491b85d5089585c8320c06aaa01444e15fbaa8ad1fab50d8249c92'
    'sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql'='71e1d870b0e7d9fb1fa23407fbc9d8f26bae44f36e005dbe38d08d415ab979d5'
    'sql_schema/dbo.usp_RunMaintenance.StoredProcedure.sql'='95d3dd730d1ac96bae96164ac92f32c9a110a5c9ae2d72daf2aad2a2ba788d25'
    'sql_schema/dbo.usp_update_stats.StoredProcedure.sql'='dbaf8e463c94e03b72aea7f0a6f8202b07f96632eb63935effee54c5ff78fb5c'
    'sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql'='07b56ac1e0d96a9f2a4d4ded0422c26dae4c0ed78e536cb754790eb4273b7c49'
    'sql_schema/dbo.usp_MaintenanceImport.StoredProcedure.sql'='b4e01f41428f0f6ecb12f2b45bf9ebbc6b822f5bc24f74c52b4dfbe82938cf15'
}
foreach($path in $expected.Keys) {
    $text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")
    $hash=[Security.Cryptography.SHA256]::Create()
    try { $actual=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if($actual -cne $expected[$path]){throw "Unreviewed D3 maintenance source: $path"}
}
Write-Output 'PASS: seven fixed D3c source candidates; no SQL connection or deployment authority.'
