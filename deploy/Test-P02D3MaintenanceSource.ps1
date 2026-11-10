param([string]$RepositoryRoot=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# Offline source custody only. This is not an installed permission/source
# allowlist or an installer; D4 must qualify the coordinated final release.
$expected=@{
    'sql_schema/dbo.MaintenanceWork.Table.sql'='8814d9af6f3592ddb3050ab737a1280cb578894ad27789e310d63775bd5f1408'
    'sql_schema/dbo.usp_MaintenanceDue.StoredProcedure.sql'='df6c5e580ad6bc1db960277bde2f5ffa8c6ef1c4da01920d54562614117619c6'
    'sql_schema/dbo.usp_MaintenancePostImport.StoredProcedure.sql'='24fea607e6b559dfd48b6517fbf8b7c98d63d2fbd01de7bb71891047faf20dca'
    'sql_schema/dbo.usp_RunMaintenance.StoredProcedure.sql'='2ea9cf5471561d09570f07613600a2df91e5cc66ac135876ee12cf789a95c196'
    'sql_schema/dbo.usp_update_stats.StoredProcedure.sql'='176e25b59c3f95d2fde30f000dba639390701d759a5d95148c00f0b3c7d8ef3f'
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
    'sql_schema/dbo.MaintenanceBackupWork.Table.sql'='e86933c25772dea13eea4fe71f9025441f4576ec986485eb64917816132cc2e1'
    'sql_schema/dbo.usp_MaintenanceFinalStats.StoredProcedure.sql'='bd008c5a76cdf4c1cc22f50c67288f4cbc914fc637c4ed0900e407efa22e6c12'
    'sql_schema/dbo.usp_MaintenanceBackupClaim.StoredProcedure.sql'='1f5ca2e36fe7a4a170834749f48efaff22cf59bf9519a1b592279bdb49afb693'
    'sql_schema/dbo.usp_MaintenanceBackupAcknowledge.StoredProcedure.sql'='d94c3d064f0885ff7275fc27d218324a2bfff80fedd1920590d7241950af7d2e'
    'sql_schema/dbo.usp_S11CompleteStatsReportsCore.StoredProcedure.sql'='d5c83d1918b50248cc24f97387431f3b6627f91296553daf822537441a4b062b'
    'sql_schema/dbo.usp_S11ValidateStatsReportStage.StoredProcedure.sql'='e52d670e90be9502fa5eb08eb5a795eb5cdc243cfbb0e6374402b8f532044e9d'
}
foreach($path in $expected.Keys) {
    $text=[IO.File]::ReadAllText((Join-Path $RepositoryRoot $path)).Replace("`r`n","`n")
    $hash=[Security.Cryptography.SHA256]::Create()
    try { $actual=([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
    if($actual -cne $expected[$path]){throw "Unreviewed D3 maintenance source: $path"}
}
Write-Output 'PASS: twenty-three fixed D3g source candidates; no SQL connection or deployment authority.'
