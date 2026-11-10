param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline source custody only. This is not an installed permission/source
# allowlist or an installer; D4 must qualify the coordinated final release.
$expected=@{
    'sql_schema/dbo.MaintenanceWork.Table.sql'='5415c834690180f5fcca45e1667de916c5b33671d9037bd55f03109c7993a4d3'
    'sql_schema/dbo.usp_MaintenanceDue.StoredProcedure.sql'='512f44bbe2491b85d5089585c8320c06aaa01444e15fbaa8ad1fab50d8249c92'
    'sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql'='24fea607e6b559dfd48b6517fbf8b7c98d63d2fbd01de7bb71891047faf20dca'
    'sql_schema/dbo.usp_RunMaintenance.StoredProcedure.sql'='a602327ff5de1fc41f2472abf13d96d1b3cb58d84c3dbe9141bce15f129b9631'
    'sql_schema/dbo.usp_update_stats.StoredProcedure.sql'='77ecfe4e6536040c510621952ed8a1991a47de0116212ae69c767d12da83b491'
    'sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql'='07b56ac1e0d96a9f2a4d4ded0422c26dae4c0ed78e536cb754790eb4273b7c49'
    'sql_schema/dbo.usp_MaintenanceImport.StoredProcedure.sql'='0913603dce65ed74f9a4c62e03d0281b70fa635345c6330851b3726a9b349db1'
    'sql_schema/dbo.CREATE_DELTA_TABLES.StoredProcedure.sql'='8b8757bc34e2ca46208ffbd6f0655cc2f49d9aa789517fdd10c71b9458bdd4f6'
    'sql_schema/dbo.MaintenanceConfigurationWork.Table.sql'='55153b6243a04cfb710d210975c318ceff77cfc2151ab0070cb8043641f26d27'
    'sql_schema/dbo.usp_MaintenanceConfigurationDue.StoredProcedure.sql'='114aa7b30bd236851ac64273f12ca3ba5deba9003bbcd49bb5cb2e5bebcc8b3b'
    'sql_schema/dbo.usp_MaintenanceConfiguration.StoredProcedure.sql'='a5735621f703128f10e99dcdcd2b775c6ee5c2857810abda495d797ae18272db'
    'sql_schema/dbo.SP_Stats_for_Upload.StoredProcedure.sql'='afbe2873e06d68e3aedd4e7a2da52692cd0f9e63f8b6e176f9b9fc6e6536cb12'
    'sql_schema/dbo.usp_MaintenancePlayerReport.StoredProcedure.sql'='e805a65e0896826ddefc215906dcb00bd0c912ff4e825ea4f3dbec9fde9d2c0c'
    'sql_schema/dbo.sp_ExcelOutput_ByKVK.StoredProcedure.sql'='75237b6b2d9625bcff6205c370b2cfedef9ff6683c6fcb7775803c3da991d650'
    'sql_schema/dbo.MaintenanceKvkWork.Table.sql'='95f683d3b6a5aeedca67ce2a307f3f19c901634d3d46a8483385adc8ab838411'
    'sql_schema/dbo.usp_MaintenanceKvkDue.StoredProcedure.sql'='5ca59625a6d6bd8577ea2a628d027e3096c57aadf510675f6ac9f25d98e1cf7f'
    'sql_schema/dbo.usp_MaintenanceKvkOutput.StoredProcedure.sql'='bdb80a53ca7722152d68b92623bfa167bdc95187ef9c8fc000024d76fb57f047'
}
foreach($path in $expected.Keys) {
    $text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")
    $hash=[Security.Cryptography.SHA256]::Create()
    try { $actual=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if($actual -cne $expected[$path]){throw "Unreviewed D3 maintenance source: $path"}
}
Write-Output 'PASS: seventeen fixed D3f source candidates; no SQL connection or deployment authority.'
