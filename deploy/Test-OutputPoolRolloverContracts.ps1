param([string]$RepositoryRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
# Offline text/contract inspection only. No SQL Server, provider or deployment calls.
$checks = 0
function Assert-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Read-Source([string]$RelativePath) {
    $path = Join-Path $RepositoryRoot $RelativePath
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) "Missing $RelativePath"
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
}
function Get-CreateParts([string]$Source) {
    $start = $Source.IndexOf('CREATE TABLE ')
    Assert-Contract ($start -ge 0) 'Missing table body'
    $end = $Source.IndexOf("`n);", $start)
    Assert-Contract ($end -gt $start) 'Missing table terminator'
    return @($Source.Substring($start, $end + 3 - $start), $Source.Substring($end + 3))
}
function Get-ExpectedBody([string]$ObjectName, [string]$Source) {
    $parts = Get-CreateParts $Source
    $body = [regex]::Replace($parts[0], '(?m)^\s*CONSTRAINT\s+\w+\s+FOREIGN KEY[^\n]+\n', '')
    $body = [regex]::Replace($body, ',\s*\n\);', "`n);")
    $body = [regex]::Replace($body, 'CONSTRAINT\s+\w+\s+', '')
    $body = $body.Replace("CREATE TABLE $ObjectName", ('CREATE TABLE #S10D_' + $ObjectName.Replace('.', '_')))
    return [regex]::Replace($body, '(\b(?:n?varchar|n?char)\([^)]*\))(?!\s+COLLATE)(\s+(?:NOT NULL|NULL))', '$1 COLLATE DATABASE_DEFAULT$2')
}

$migration = Read-Source 'migrations/20260915_001_kvk_output_pool_rollover.sql'
$fixture = Read-Source 'validation/kvk_source/s10_output_pool_rollover.sql'
$payloadMatch = [regex]::Match($migration, "(?s)-- S10D_INSTALL_PAYLOAD_BEGIN[^\n]*\nEXEC sys\.sp_executesql N'((?:''|[^'])*)';\n-- S10D_INSTALL_PAYLOAD_END")
Assert-Contract $payloadMatch.Success 'Missing constant, guarded installation payload'
$payload = $payloadMatch.Groups[1].Value.Replace("''", "'")
$newObjects = @('KVK.SourceOutputFile','KVK.SourceOutputPool','KVK.SourceOutputSlot','KVK.SourceOutputDisposition')
$inheritedObjects = @('KVK.SeasonSource','KVK.SourceRouting','KVK.SourceDelivery','KVK.SourcePublication',
    'dbo.ExportJob','dbo.ExportResource','dbo.ExportJobResource','dbo.ExportRequestBudget',
    'dbo.ExportAttempt','dbo.ExportAttemptPart','dbo.ExportPreparation','dbo.ExportPreparationResource')
$sources = @{}
$newKeys = @{
    'dbo.ExportAttempt' = 'CONSTRAINT UQ_ExportAttempt_JobEpoch UNIQUE (AttemptID, JobID, Epoch)'
    'dbo.ExportAttemptPart' = 'CONSTRAINT UQ_ExportAttemptPart_NumberFile UNIQUE (AttemptID, PartNo, FileID)'
}
foreach ($object in @($inheritedObjects) + @($newObjects)) {
    $source = Read-Source "sql_schema/$object.Table.sql"
    $sources[$object] = $source
    $baseline = $source
    if ($newKeys.ContainsKey($object)) {
        $key = $newKeys[$object]
        Assert-Contract ($source.Contains($key + ',')) "Missing additive snapshot key: $object"
        Assert-Contract ($payload.Contains("ALTER TABLE $object ADD $key;")) "Missing additive install key: $object"
        $baseline = [regex]::Replace($baseline, '(?m)^\s*' + [regex]::Escape($key) + ',\n', '')
    }
    $expected = Get-ExpectedBody $object $baseline
    Assert-Contract ($migration.Contains($expected)) "Expected metadata body differs from accepted snapshot: $object"
    $parts = Get-CreateParts $source
    if ($object -in $newObjects) {
        Assert-Contract ($payload.Contains($parts[0])) "Table/migration drift: $object"
        Assert-Contract ($payload.Contains($parts[1].Trim())) "Index/FK migration drift: $object"
    }
    foreach ($line in ($parts[1] -split "`n" | Where-Object { $_ -match '^CREATE (UNIQUE )?INDEX ' })) {
        $expectedIndex = [regex]::Replace($line, '(\bON\s+)' + [regex]::Escape($object) + '(?=\s|\()', ('${1}#S10D_' + $object.Replace('.', '_')))
        Assert-Contract ($migration.Contains($expectedIndex)) "Expected index omitted: $object"
    }
}
Assert-Contract (([regex]::Matches($payload,'CREATE TABLE ')).Count -eq 4) 'Unexpected installation table set'
Assert-Contract (([regex]::Matches($payload,'ALTER TABLE dbo\.')).Count -eq 2) 'Unexpected inherited alteration'
foreach ($value in @('RequiresBackup: Yes','RiskLevel: High','Rollback: Forward Fix Only','DataChange: No','DataSafetyPlan: Included',
    'CreatedUtc: 2026-09-15','EstimatedRowsAffected: 0 existing application rows',
    '@S10DExisting NOT IN (0,4)',"AND type<>'U'",'IF @S10DOwnTransaction=1 COMMIT TRANSACTION',
    'IF @S10DOwnTransaction=1 AND XACT_STATE()<>0 ROLLBACK TRANSACTION',"@LockOwner='Transaction'",'@LockTimeout=0',
    'c.definition COLLATE Latin1_General_100_BIN2','is_not_trusted','is_not_for_replication','is_disabled',
    'ORDER BY ic.index_column_id FOR JSON PATH','default shape conflict','check count conflict','c.user_type_id<>c.system_type_id')) {
    Assert-Contract ($migration.Contains($value)) "Missing migration guarantee: $value"
}
$outsidePayload = $migration.Remove($payloadMatch.Index, $payloadMatch.Length)
Assert-Contract ($outsidePayload -notmatch '(?im)^\s*CREATE\s+(?:UNIQUE\s+)?INDEX\s+\S+\s+ON\s+(?:dbo|KVK)\.') 'Permanent index DDL outside guarded payload'
Assert-Contract ($outsidePayload -notmatch '(?im)^\s*(?:CREATE|ALTER|DROP)\s+TABLE\s+(?:dbo|KVK)\.') 'Permanent table DDL outside guarded payload'
Assert-Contract ($migration.IndexOf('foreign key shape conflict') -lt $migration.IndexOf('-- S10D_INSTALL_PAYLOAD_BEGIN')) 'Permanent DDL precedes inherited validation'
Assert-Contract ($migration.Contains('IF @S10DExisting=0 AND @S10DPass=0')) 'Missing first-install versus exact-rerun branch'
Assert-Contract ($migration -notmatch '(?im)^\s*(INSERT(?:\s+INTO)?|UPDATE|DELETE\s+FROM|MERGE|TRUNCATE\s+TABLE)\s+(?:dbo|KVK)\.') 'Migration mutates existing application data'
Assert-Contract ($migration -notmatch '(?im)^\s*(GRANT|DENY|REVOKE|USE|GO\s*$|:)\b') 'Unexpected permission, database or SQLCMD operation'
Assert-Contract ($migration -notmatch '(?im)^\s*DROP\s+TABLE\s+(?!#)') 'Destructive rollback or permanent drop'
Assert-Contract ($migration -notmatch 'sp_addextendedproperty|sp_updateextendedproperty') 'Observed metadata must not be blindly sealed'

$fkPattern = 'CONSTRAINT\s+(\w+)\s+FOREIGN KEY\s*\(([^)]+)\)\s+REFERENCES\s+([\w.]+)\s*\(([^)]+)\)'
foreach ($object in $sources.Keys) {
    foreach ($fk in [regex]::Matches($sources[$object], $fkPattern)) {
        $name = $fk.Groups[1].Value
        $columns = @($fk.Groups[2].Value.Split(',') | ForEach-Object { $_.Trim() })
        $target = $fk.Groups[3].Value
        $references = @($fk.Groups[4].Value.Split(',') | ForEach-Object { $_.Trim() })
        Assert-Contract ($columns.Count -eq $references.Count) "FK arity mismatch: $name"
        for ($n = 0; $n -lt $columns.Count; $n++) {
            $row = "(N'$object',N'$name',$($n+1),N'$($columns[$n])',N'$target',N'$($references[$n])')"
            Assert-Contract ($migration.Contains($row)) "Expected FK mapping omitted: $name/$($columns[$n])"
        }
        if ($object -notin $newObjects) { continue }
        if (-not $sources.ContainsKey($target)) { $sources[$target] = Read-Source "sql_schema/$target.Table.sql" }
        for ($n = 0; $n -lt $columns.Count; $n++) {
            $columnPattern = '(?m)^\s*\[?{0}\]?\s+(.+?)\s+(?:NOT NULL|NULL)[,\n]'
            $left = [regex]::Match($sources[$object], ($columnPattern -f [regex]::Escape($columns[$n])))
            $right = [regex]::Match($sources[$target], ($columnPattern -f [regex]::Escape($references[$n])))
            Assert-Contract ($left.Success -and $right.Success -and $left.Groups[1].Value -ceq $right.Groups[1].Value) "FK type/collation mismatch: $name/$($columns[$n])"
        }
        $keys = [regex]::Matches($sources[$target], '(?:PRIMARY KEY|UNIQUE)\s*\(([^)]+)\)')
        $wanted = $references -join ','
        $matches = @($keys | Where-Object { ($_.Groups[1].Value -replace '\s','') -ceq $wanted })
        Assert-Contract ($matches.Count -ge 1) "FK has no exact eligible target key: $name"
    }
}
foreach ($value in @('FileID nvarchar(128) COLLATE Latin1_General_100_BIN2','UQ_SourceOutputFile_Kind','destination:','DATALENGTH(FileID) / 2')) {
    Assert-Contract ($sources['KVK.SourceOutputFile'].Contains($value)) "Missing common identity guarantee: $value"
}
foreach ($value in @('RegistrationNo BETWEEN 1 AND 8','FK_SourceOutputPool_Index','FK_SourceOutputPool_Choice')) {
    Assert-Contract ($sources['KVK.SourceOutputPool'].Contains($value)) "Missing pool guarantee: $value"
}
foreach ($value in @('SlotNo BETWEEN 1 AND 16','FK_SourceOutputSlot_Assignment','FK_SourceOutputSlot_Disposition','FK_SourceOutputSlot_Part')) {
    Assert-Contract ($sources['KVK.SourceOutputSlot'].Contains($value)) "Missing slot guarantee: $value"
}
foreach ($value in @('FK_SourceOutputDisposition_Job','FK_SourceOutputDisposition_Attempt','FK_SourceOutputDisposition_Membership','FK_SourceOutputDisposition_LegacyDelivery','FK_SourceOutputDisposition_LegacyPublication','NewEpoch - OldEpoch BETWEEN 0 AND 1')) {
    Assert-Contract ($sources['KVK.SourceOutputDisposition'].Contains($value)) "Missing evidence scope guarantee: $value"
}
Assert-Contract ($sources['KVK.SourceOutputDisposition'] -notmatch 'REFERENCES KVK.SourceOutputPool\s*\([^)]*(?:Epoch|ActiveKVK|ChoiceID)') 'History references mutable current pool scope'
foreach ($value in @('S10D_AUTHORIZED','S10D_SERVER','S10D_DATABASE','K98[_]S10D[_]Disposable[_]%',
    'ExpectedUtf16Hash','BackupEvidence','RestoreEvidence','HASHBYTES','@@TRANCOUNT<>0','ROLLBACK TRANSACTION',
    'inherited_drift','preservation','ERROR_NUMBER()<>51500','9000000','9000001','cas_stale_owner','append_event_preserves_assignment')) {
    Assert-Contract ($fixture.Contains($value)) "Missing authored fixture contract: $value"
}
Assert-Contract ($fixture -notmatch '(?i)OPENROWSET|BULK INSERT|xp_cmdshell|Invoke-Sqlcmd') 'Fixture obtains unreviewed external input'
Assert-Contract ($sources['dbo.ExportResource'].Contains('ActivePreparationID IS NULL AND OwnerID IS NULL') -and $sources['dbo.ExportResource'].Contains('FK_ExportResource_PreparationMembership')) 'S10C ownership extension lost'
Write-Output "S10D offline contracts passed: $checks checks. No SQL, provider or Discord execution."
