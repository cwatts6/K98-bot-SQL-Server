param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline source custody only. This is not an installed permission/source
# allowlist or an installer; D4 must qualify the coordinated final release.
$expected=@{
    'sql_schema/dbo.MaintenanceWork.Table.sql'='5415c834690180f5fcca45e1667de916c5b33671d9037bd55f03109c7993a4d3'
    'sql_schema/dbo.usp_MaintenanceDue.StoredProcedure.sql'='512f44bbe2491b85d5089585c8320c06aaa01444e15fbaa8ad1fab50d8249c92'
    'sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql'='24fea607e6b559dfd48b6517fbf8b7c98d63d2fbd01de7bb71891047faf20dca'
    'sql_schema/dbo.usp_RunMaintenance.StoredProcedure.sql'='b44b423e781fcf867f1c877a6823d333410effcd5edcd0318a4ebda6f53ead1d'
    'sql_schema/dbo.usp_update_stats.StoredProcedure.sql'='b9d41bb13c197712405d610730fbc8d656dce5656facb8be20a01fd179c1899c'
    'sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql'='07b56ac1e0d96a9f2a4d4ded0422c26dae4c0ed78e536cb754790eb4273b7c49'
    'sql_schema/dbo.usp_MaintenanceImport.StoredProcedure.sql'='0913603dce65ed74f9a4c62e03d0281b70fa635345c6330851b3726a9b349db1'
    'sql_schema/dbo.CREATE_DELTA_TABLES.StoredProcedure.sql'='8b8757bc34e2ca46208ffbd6f0655cc2f49d9aa789517fdd10c71b9458bdd4f6'
    'sql_schema/dbo.MaintenanceConfigurationWork.Table.sql'='55153b6243a04cfb710d210975c318ceff77cfc2151ab0070cb8043641f26d27'
    'sql_schema/dbo.usp_MaintenanceConfigurationDue.StoredProcedure.sql'='114aa7b30bd236851ac64273f12ca3ba5deba9003bbcd49bb5cb2e5bebcc8b3b'
    'sql_schema/dbo.usp_MaintenanceConfiguration.StoredProcedure.sql'='80b03e934e04d2c9915805be589dd300241d593194af141445a501e45d5fbbee'
}
foreach($path in $expected.Keys) {
    $text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")
    $hash=[Security.Cryptography.SHA256]::Create()
    try { $actual=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if($actual -cne $expected[$path]){throw "Unreviewed D3 maintenance source: $path"}
}
Write-Output 'PASS: eleven fixed D3d source candidates; no SQL connection or deployment authority.'
