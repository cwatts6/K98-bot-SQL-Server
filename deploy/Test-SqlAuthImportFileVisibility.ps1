[CmdletBinding()]
param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$migration = [IO.File]::ReadAllText((Join-Path $RepositoryRoot 'migrations/20261008_001_sql_auth_import_file_visibility.sql'))
$rows = [regex]::Matches($migration, "\(N'dbo\.(?<name>[A-Z_0-9]+)', 0x(?<before>[A-F0-9]{64}), 0x(?<after>[A-F0-9]{64}), N'(?<body>(?:[^']|'')*)'\);", [Text.RegularExpressions.RegexOptions]::Singleline)
if ($rows.Count -ne 3) { throw 'Exactly three reviewed module bodies required' }
$counts = @{ ARCHIVE_IMPORT_STAGING_FILE=4; CLAIM_KS4_IMPORT_FILE=6; IMPORT_STAGING_PROC_CORE=1 }
function Get-DefinitionHash([string]$Definition) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::Unicode.GetBytes($Definition)))).Replace('-','') }
    finally { $sha.Dispose() }
}
foreach ($row in $rows) {
    $name = $row.Groups['name'].Value
    if (-not $counts.ContainsKey($name)) { throw 'Unexpected migration module' }
    $body = $row.Groups['body'].Value.Replace("''", "'")
    $stored = [regex]::Replace($body,'^ALTER PROCEDURE','CREATE PROCEDURE')
    if ((Get-DefinitionHash $stored) -cne $row.Groups['after'].Value) { throw "Exact postimage bytes differ: $name" }
    $source = [IO.File]::ReadAllText((Join-Path $RepositoryRoot "sql_schema/dbo.$name.StoredProcedure.sql")).Replace("`r`n", "`n")
    $source = $source.Substring($source.IndexOf('ALTER PROCEDURE')).TrimEnd().Replace("`n", "`r`n")
    if ($body -cne $source) { throw "Migration/source definition differs: $name" }
    $pattern = 'SET (@\w+) = COALESCE\(\(SELECT file_exists FROM sys\.dm_os_file_exists\((@\w+)\)\), 0\);'
    if ([regex]::Matches($body,$pattern).Count -ne $counts[$name] -or $body.Contains('xp_fileexist')) { throw "Incomplete lifecycle replacement: $name" }
    $before = [regex]::Replace($body,$pattern,'EXEC master.dbo.xp_fileexist $2, $1 OUTPUT;')
    $before = [regex]::Replace($before,'^ALTER PROCEDURE','CREATE PROCEDURE')
    if ((Get-DefinitionHash $before) -cne $row.Groups['before'].Value) { throw "Changes beyond reviewed file metadata calls: $name" }
}
foreach ($guard in @('Execution sessions must be closed','sys.crypt_properties','execute_as_principal_id IS NOT NULL','uses_ansi_nulls<>1','uses_quoted_identifier<>1',"HASHBYTES('SHA2_256',N'CREATE'+SUBSTRING(Body,6,DATALENGTH(Body)/2))<>AfterHash",'ROLLBACK TRANSACTION','K98:S11:schema')) {
    if (-not $migration.Contains($guard)) { throw "Missing migration guard: $guard" }
}
Write-Output 'PASS: Three exact source/postimage definitions; eleven replacements; inverse production hashes and deployment guards. No SQL connection or workflow replay.'
