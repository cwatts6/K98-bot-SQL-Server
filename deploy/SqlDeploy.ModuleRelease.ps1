# Bounded declarative profile. Never executes a general migration SQL script.
# The caller pins this runner, profile bytes and every module from one SQL commit.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-K98ModuleHash([byte[]]$Bytes) {
    $h=[Security.Cryptography.SHA256]::Create()
    try {return ([BitConverter]::ToString($h.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()} finally {$h.Dispose()}
}
function Assert-K98ModuleFields($Value,[string[]]$Fields) {
    if((@($Value.PSObject.Properties.Name|Sort-Object) -join ',') -cne (@($Fields|Sort-Object) -join ',')){throw 'Exact module release fields required'}
}
function Read-K98ModuleProfile([string]$Path,[string]$Expected,[string]$MigrationId) {
    $raw=[IO.File]::ReadAllBytes($Path)
    if($raw.Length -gt 1MB -or $Expected -cnotmatch '^[a-f0-9]{64}$' -or (Get-K98ModuleHash $raw) -cne $Expected){throw 'Profile checksum/size differs'}
    $p=[Text.UTF8Encoding]::new($false,$true).GetString($raw)|ConvertFrom-Json
    Assert-K98ModuleFields $p @('version','profile','migration_id','database_collation','tempdb_collation','compatibility_level','modules','grants','requires')
    if($p.version -ne 1 -or $p.profile -cne 'module_grants_v1' -or $p.migration_id -cne $MigrationId -or $MigrationId -cnotmatch '^[0-9]{8}_[0-9]{3}_[a-z0-9_]+$'){throw 'Unsupported exact migration/profile'}
    if($p.database_collation -cnotmatch '^[A-Za-z0-9_]{1,128}$' -or $p.tempdb_collation -cnotmatch '^[A-Za-z0-9_]{1,128}$' -or $p.compatibility_level -notin @(130,140,150,160)){throw 'Exact SQL collation/compatibility required'}
    if(@($p.modules).Count -gt 32 -or @($p.grants).Count -gt 32 -or (@($p.modules).Count+@($p.grants).Count) -lt 1 -or @($p.requires).Count -gt 64){throw 'Bounded nonempty SQL profile required'}
    $seen=@{};$texts=@{}
    foreach($m in $p.modules) {
        Assert-K98ModuleFields $m @('schema','name','type','before_sha256','file','sha256')
        foreach($v in @($m.schema,$m.name)){if($v -cnotmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$'){throw 'Ordinary SQL identifier required'}}
        $key=$m.schema+'.'+$m.name
        if($seen.ContainsKey($key) -or $m.type -cnotin @('P','V') -or $m.before_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $m.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $m.file -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,120}\.sql$'){throw ('Unsupported module '+$key)}
        $seen[$key]=$true
        $file=Join-Path (Split-Path -Parent $Path) $m.file
        $item=Get-Item -LiteralPath $file -Force
        if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 2MB){throw ('Unsupported module file '+$m.file)}
        $bytes=[IO.File]::ReadAllBytes($file)
        if((Get-K98ModuleHash $bytes) -cne $m.sha256){throw ('Module file checksum differs: '+$m.file)}
        $text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
        $kind=if($m.type -ceq 'P'){'PROCEDURE'}else{'VIEW'}
        $prefix='CREATE OR ALTER '+$kind+' ['+$m.schema+'].['+$m.name+']'
        # One module definition is one driver batch. No GO splitting or encoding/
        # newline normalization, SQLCMD prelude, CLR, triggers or DML migration.
        if(-not $text.StartsWith($prefix,[StringComparison]::Ordinal) -or $text.Substring($prefix.Length) -notmatch '^\s' -or $text -match '(?im)^\s*(GO(?:\s|$)|:)' -or $text -match '(?i)\b(ENCRYPTION|EXTERNAL\s+NAME)\b'){throw ('Unsupported single module definition: '+$key)}
        $texts[$key]=$text
    }
    $seen=@{}
    foreach($g in $p.grants) {
        Assert-K98ModuleFields $g @('schema','name','principal','permission','before')
        foreach($v in @($g.schema,$g.name,$g.principal)){if($v -cnotmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$'){throw 'Ordinary grant identifier required'}}
        $key=$g.schema+'.'+$g.name+':'+$g.principal+':'+$g.permission
        if($seen.ContainsKey($key) -or $g.permission -cnotin @('EXECUTE','SELECT') -or $g.before -cne 'ABSENT'){throw ('Only explicit new object grants supported: '+$key)}
        $seen[$key]=$true
    }
    foreach($r in $p.requires) {
        Assert-K98ModuleFields $r @('migration_id','sha256','status')
        if($r.migration_id -cnotmatch '^[0-9]{8}_[0-9]{3}_[A-Za-z0-9_]+$' -or $r.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $r.status -cnotin @('Applied','Failed')){throw 'Exact predecessor history required'}
    }
    return @{Profile=$p;Texts=$texts}
}
function Invoke-K98ModuleQuery($Connection,$Transaction,[string]$Sql,[hashtable]$Values=@{}) {
    $cmd=$Connection.CreateCommand();$cmd.CommandText=$Sql;$cmd.CommandTimeout=30
    if($null -ne $Transaction){$cmd.Transaction=$Transaction}
    foreach($key in $Values.Keys){[void]$cmd.Parameters.AddWithValue('@'+$key,$Values[$key])}
    $reader=$null;$rows=[Collections.Generic.List[object]]::new()
    try {
        $reader=$cmd.ExecuteReader()
        do {
            while($reader.Read()) {
                if($rows.Count -ge 256){throw 'SQL profile result exceeded bound'}
                $row=[ordered]@{}
                for($i=0;$i -lt $reader.FieldCount;$i++){$v=$reader.GetValue($i);if($v -is [DBNull]){$v=$null};$row[$reader.GetName($i)]=$v}
                $rows.Add([pscustomobject]$row)
            }
        }while($reader.NextResult())
        return ,$rows.ToArray()
    }finally{if($null -ne $reader){$reader.Dispose()};$cmd.Dispose()}
}
function Assert-K98ModuleEnvironment($Connection,$Transaction,$Profile,[switch]$Backup) {
    $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT CAST(DATABASEPROPERTYEX(DB_NAME(),'Collation') AS nvarchar(128)) AS db_collation,
CAST(DATABASEPROPERTYEX('tempdb','Collation') AS nvarchar(128)) AS temp_collation,
compatibility_level FROM sys.databases WHERE database_id=DB_ID();
'@
    $e=$rows[0]
    foreach($pair in @(@('database_collation','db_collation'),@('tempdb_collation','temp_collation'),@('compatibility_level','compatibility_level'))) {
        if([string]$Profile.($pair[0]) -cne [string]$e.($pair[1])){throw ('SQL compatibility '+$pair[0]+' expected='+$Profile.($pair[0])+' observed='+$e.($pair[1]))}
    }
    # DDL triggers could perform effects outside this bounded profile. Refuse
    # instead of claiming transaction rollback proves those effects absent.
    $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL OR OBJECT_ID(N'dbo.DeploymentRunHistory',N'U') IS NULL
 THROW 51950,'Existing deployment history tables are required.',1;
IF HAS_PERMS_BY_NAME(NULL,NULL,'VIEW ANY DEFINITION')<>1 OR HAS_PERMS_BY_NAME(DB_NAME(),'DATABASE','VIEW DEFINITION')<>1
 THROW 51950,'Deployment metadata visibility is required.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_class=0 AND is_disabled=0)
 OR EXISTS(SELECT 1 FROM sys.server_triggers WHERE is_disabled=0)
 THROW 51950,'Enabled DDL triggers are unsupported by module_grants_v1.',1;
IF EXISTS(SELECT 1 FROM sys.triggers WHERE parent_id IN (OBJECT_ID(N'dbo.SchemaMigrationHistory'),OBJECT_ID(N'dbo.DeploymentRunHistory')) AND is_disabled=0)
 THROW 51950,'Deployment ledger triggers are unsupported by module_grants_v1.',1;
'@
    foreach($r in $Profile.requires) {
        $rows=Invoke-K98ModuleQuery $Connection $Transaction 'SELECT Status,ChecksumSha256 FROM dbo.SchemaMigrationHistory WHERE MigrationId=@id;' @{id=$r.migration_id}
        if($rows.Count -ne 1 -or $rows[0].Status -cne $r.status -or $rows[0].ChecksumSha256 -cne $r.sha256){throw ('Required migration differs: '+$r.migration_id+' expected='+$r.status+'/'+$r.sha256)}
    }
    if($Backup) {
        $null=Invoke-K98ModuleQuery $Connection $Transaction @'
IF NOT EXISTS(SELECT 1 FROM msdb.dbo.backupset WHERE database_name=DB_NAME() COLLATE DATABASE_DEFAULT
 AND type='D' AND is_damaged=0 AND backup_finish_date>=DATEADD(hour,-24,GETDATE()))
 THROW 51950,'Full backup within 24 hours required before drain/apply.',1;
IF (SELECT recovery_model_desc FROM sys.databases WHERE database_id=DB_ID())<>'SIMPLE'
 AND NOT EXISTS(SELECT 1 FROM msdb.dbo.backupset WHERE database_name=DB_NAME() COLLATE DATABASE_DEFAULT
 AND type='L' AND is_damaged=0 AND backup_finish_date>=DATEADD(minute,-30,GETDATE()))
 THROW 51950,'Log backup within 30 minutes required before drain/apply.',1;
'@
    }
}
function Assert-K98ModuleImages($Connection,$Transaction,$Loaded,[bool]$After) {
    foreach($m in $Loaded.Profile.modules) {
        $key=$m.schema+'.'+$m.name
        $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT o.type,m.definition,m.uses_ansi_nulls,m.uses_quoted_identifier,
(SELECT COUNT(*) FROM sys.crypt_properties c WHERE c.class=1 AND c.major_id=o.object_id) AS signatures
FROM sys.objects o JOIN sys.sql_modules m ON m.object_id=o.object_id WHERE o.object_id=OBJECT_ID(@name);
'@ @{name=$key}
        # SQL Server stores CREATE OR ALTER as CREATE plus three spaces. Derive
        # that documented syntax representation from reviewed bytes only; never
        # normalize body/line endings or adopt an observed definition as expected.
        $expected=if($After){Get-K98ModuleHash ([Text.Encoding]::Unicode.GetBytes(('CREATE   '+$Loaded.Texts[$key].Substring(16))))}else{$m.before_sha256}
        $observed=if($rows.Count -eq 1 -and $null -ne $rows[0].definition){Get-K98ModuleHash ([Text.Encoding]::Unicode.GetBytes($rows[0].definition))}else{'MISSING_OR_INVISIBLE'}
        if($rows.Count -ne 1 -or $observed -cne $expected -or $rows[0].type.Trim() -cne $m.type -or $rows[0].signatures -ne 0 -or -not $rows[0].uses_ansi_nulls -or -not $rows[0].uses_quoted_identifier){throw ('Module '+$key+' expected='+$expected+' observed='+$observed+'; inspect exact definition/settings/signatures. Do not substitute observed hashes.')}
    }
    foreach($g in $Loaded.Profile.grants) {
        $rows=Invoke-K98ModuleQuery $Connection $Transaction @'
SELECT o.type,p.type AS principal_type,dp.state
FROM sys.objects o CROSS JOIN sys.database_principals p
LEFT JOIN sys.database_permissions dp ON dp.class=1 AND dp.major_id=o.object_id AND dp.minor_id=0 AND dp.grantee_principal_id=p.principal_id AND dp.permission_name=@permission
WHERE o.object_id=OBJECT_ID(@name) AND p.name=@principal;
'@ @{name=($g.schema+'.'+$g.name);principal=$g.principal;permission=$g.permission}
        $expected=if($After){'G'}else{$null}
        if($rows.Count -ne 1 -or $rows[0].state -cne $expected -or $rows[0].principal_type -cnotin @('S','U') -or $rows[0].type.Trim() -cnotin @('P','V')){throw ('Grant differs: '+$g.schema+'.'+$g.name+'/'+$g.principal+'/'+$g.permission+' expected='+$(if($After){'GRANT'}else{'ABSENT'}))}
    }
}
function Get-K98ModuleOutcome($Connection,$Loaded,[string]$Hash,[string]$Commit,[string]$ReleaseId) {
    $p=$Loaded.Profile
    $rows=Invoke-K98ModuleQuery $Connection $null 'SELECT Status,ChecksumSha256,GitCommit,DeploymentId FROM dbo.SchemaMigrationHistory WHERE MigrationId=@id;' @{id=$p.migration_id}
    if($rows.Count) {
        if($rows.Count -ne 1 -or $rows[0].Status -cne 'Applied' -or $rows[0].ChecksumSha256 -cne $Hash -or $rows[0].GitCommit -cne $Commit){throw ('Migration history differs: '+$p.migration_id+' expected=Applied/'+$Hash+'/'+$Commit+'; preserve Failed history and use a reviewed corrective identity.')}
        $completed=Invoke-K98ModuleQuery $Connection $null "SELECT Status,GitCommit,ErrorMessage FROM dbo.DeploymentRunHistory WHERE DeploymentId=@attempt AND BranchName=N'module_grants_v1';" @{attempt=$rows[0].DeploymentId}
        if($completed.Count -ne 1 -or $completed[0].Status -cne 'Succeeded' -or $completed[0].GitCommit -cne $Commit){throw ('Committed migration attempt differs: '+$p.migration_id+'; retain history and inspect its linked deployment attempt.')}
        $binding=$completed[0].ErrorMessage|ConvertFrom-Json
        if($binding.migration_id -cne $p.migration_id -or $binding.profile_sha256 -cne $Hash -or $binding.sql_commit -cne $Commit -or $binding.release_id -cne $ReleaseId){throw ('Committed migration release differs: '+$p.migration_id+' expected_release='+$ReleaseId+' observed_release='+$binding.release_id+'; resume the original release, do not replay or adopt its receipt.')}
        Assert-K98ModuleImages $Connection $null $Loaded $true
        return 'committed'
    }
    $attempts=Invoke-K98ModuleQuery $Connection $null "SELECT Status,ErrorMessage FROM dbo.DeploymentRunHistory WHERE BranchName=N'module_grants_v1' AND JSON_VALUE(ErrorMessage,'$.migration_id')=@id;" @{id=$p.migration_id}
    foreach($a in $attempts) {
        $b=$a.ErrorMessage|ConvertFrom-Json
        if($b.profile_sha256 -cne $Hash -or $b.sql_commit -cne $Commit -or $b.release_id -cne $ReleaseId -or $a.Status -cnotin @('Started','Failed')){throw ('Migration attempt identity/outcome differs: '+$p.migration_id)}
    }
    Assert-K98ModuleImages $Connection $null $Loaded $false
    # The exclusive session lock has been acquired. Every possible change and
    # Applied receipt is in the SAME transaction. Its absence plus exact preimage
    # therefore proves rollback even if the prior process died before recording it.
    if($attempts.Count){return 'rolled_back'}
    return 'unstarted'
}
function Invoke-K98ModuleRelease([string]$ServerName,[string]$DatabaseName,[string]$MigrationId,[string]$ProfilePath,[string]$ProfileSHA256,[string]$ExpectedCommit,[string]$ReleaseId,[string]$Operation) {
    if($ExpectedCommit -cnotmatch '^[a-f0-9]{40}$' -or ([guid]$ReleaseId).ToString() -cne $ReleaseId -or $Operation -cnotin @('Preflight','Status','Verify','Apply')){throw 'Exact release identity and operation required'}
    $loaded=Read-K98ModuleProfile $ProfilePath $ProfileSHA256 $MigrationId
    $builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source']=$ServerName;$builder['Initial Catalog']=$DatabaseName;$builder['Integrated Security']=$true
    $builder['Encrypt']=$true;$builder['TrustServerCertificate']=$true;$builder['Connect Timeout']=10;$builder['Application Name']='K98_Module_Release_v1'
    $connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    $transaction=$null;$attempt=$null;$commitRequested=$false
    try {
        $connection.Open()
        $null=Invoke-K98ModuleQuery $connection $null @'
SET XACT_ABORT ON; SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET LOCK_TIMEOUT 5000;
DECLARE @result int;
EXEC @result=sys.sp_getapplock @Resource=N'K98_Module_Release_v1',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
IF @result<0 THROW 51950,'SQL_RELEASE_BUSY: active or unresolved SQL owner; wait, then inspect status.',1;
'@
        Assert-K98ModuleEnvironment $connection $null $loaded.Profile
        $state=Get-K98ModuleOutcome $connection $loaded $ProfileSHA256 $ExpectedCommit $ReleaseId
        if($state -cne 'committed' -and $Operation -in @('Preflight','Apply')){Assert-K98ModuleEnvironment $connection $null $loaded.Profile -Backup}
        if($Operation -ceq 'Apply' -and $state -cne 'committed') {
            $attempt=[guid]::NewGuid().ToString()
            $binding=@{migration_id=$MigrationId;profile_sha256=$ProfileSHA256;sql_commit=$ExpectedCommit;release_id=$ReleaseId}|ConvertTo-Json -Compress
            $null=Invoke-K98ModuleQuery $connection $null @'
INSERT dbo.DeploymentRunHistory(DeploymentId,StartedAtUtc,StartedBy,MachineName,DatabaseName,GitCommit,BranchName,MigrationCount,Status,ErrorMessage)
VALUES(@attempt,SYSUTCDATETIME(),ORIGINAL_LOGIN(),HOST_NAME(),DB_NAME(),@commit,N'module_grants_v1',1,N'Started',@binding);
'@ @{attempt=$attempt;commit=$ExpectedCommit;binding=$binding}
            $transaction=$connection.BeginTransaction()
            Assert-K98ModuleImages $connection $transaction $loaded $false
            foreach($m in $loaded.Profile.modules){$null=Invoke-K98ModuleQuery $connection $transaction $loaded.Texts[($m.schema+'.'+$m.name)]}
            foreach($g in $loaded.Profile.grants){$null=Invoke-K98ModuleQuery $connection $transaction ('GRANT '+$g.permission+' ON OBJECT::['+$g.schema+'].['+$g.name+'] TO ['+$g.principal+'];')}
            Assert-K98ModuleImages $connection $transaction $loaded $true
            $null=Invoke-K98ModuleQuery $connection $transaction @'
INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,AppliedBy,MachineName,GitCommit,BranchName,DeploymentId,Status,DurationMs)
VALUES(@id,@file,@hash,SYSUTCDATETIME(),ORIGINAL_LOGIN(),HOST_NAME(),@commit,N'module_grants_v1',@attempt,N'Applied',0);
UPDATE dbo.DeploymentRunHistory SET Status=N'Succeeded',FinishedAtUtc=SYSUTCDATETIME() WHERE DeploymentId=@attempt AND Status=N'Started';
'@ @{id=$MigrationId;file=($MigrationId+'.release.json');hash=$ProfileSHA256;commit=$ExpectedCommit;attempt=$attempt}
            $commitRequested=$true
            $transaction.Commit();$transaction.Dispose();$transaction=$null
            $state=Get-K98ModuleOutcome $connection $loaded $ProfileSHA256 $ExpectedCommit $ReleaseId
        }
        $code=switch($state){'committed'{0};'unstarted'{10};'rolled_back'{11};default{20}}
        $result=@{migration_id=$MigrationId;state=$state;sql_commit=$ExpectedCommit;profile_sha256=$ProfileSHA256;next_action=$(if($state -ceq 'committed'){'Continue remaining release stages; do not apply SQL again.'}else{'Same reviewed release may continue after drain.'})}
        Write-Host ($result|ConvertTo-Json -Compress)
        if($Operation -ceq 'Preflight'){return 0}
        return $code
    }catch {
        if($null -ne $transaction -and -not $commitRequested) {
            try {
                $transaction.Rollback();$transaction.Dispose();$transaction=$null
                $null=Invoke-K98ModuleQuery $connection $null "UPDATE dbo.DeploymentRunHistory SET Status=N'Failed',FinishedAtUtc=SYSUTCDATETIME() WHERE DeploymentId=@attempt AND Status=N'Started';" @{attempt=$attempt}
            }catch {Write-Warning 'Rollback acknowledgement unavailable; inspect same-release status before further action.'}
        }
        throw
    }finally{if($null -ne $transaction){$transaction.Dispose()};$connection.Dispose()}
}
