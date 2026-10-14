# Offline tests of the production declarative parser; never connects to SQL.
param([Parameter(Mandatory=$true)][string]$FixturePath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. "$PSScriptRoot\SqlDeploy.ModuleRelease.ps1"
$root=Join-Path ([IO.Path]::GetTempPath()) ('k98-tables-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root)
$checks=0
foreach($damage in @('none','hash','raw-sql','identifier','identifier-newline','type','collation','duplicate-table','duplicate-column','nullable-key','null-key','empty-key-array','key-array','scalar-key','check-op','check-column','check-literal','check-unicode','future-fk','fk-arity','fk-no-target-key','fk-target-order','fk-target-missing','fk-target-type','fk-target-collation','fk-target-length','fk-schema-case','fk-table-case','constraint','version','boolean-version','ledger')){
    $p=[IO.File]::ReadAllText($FixturePath)|ConvertFrom-Json
    switch($damage){
        'raw-sql'{$p|Add-Member NoteProperty sql 'DROP TABLE dbo.Example'}
        'identifier'{$p.tables[0].name='Bad];SELECT 1;--'}
        'identifier-newline'{$p.tables[0].name="Bad`n"}
        'type'{$p.tables[0].columns[0].type='int);DROP TABLE X;--'}
        'collation'{$p.tables[0].columns[1].collation='Latin1_General_CI_AS;SELECT 1'}
        'duplicate-table'{$p.tables+=@($p.tables[0])}
        'duplicate-column'{$p.tables[0].columns+=@($p.tables[0].columns[0])}
        'nullable-key'{$p.tables[0].columns[0].nullable=$true}
        'null-key'{$p.tables[0].primary_key=$null}
        'empty-key-array'{$p.tables[0].primary_key=@()}
        'key-array'{$p.tables[0].primary_key=@($p.tables[0].primary_key)}
        'scalar-key'{$p.tables[0].primary_key='PK_invalid'}
        'check-op'{$p.tables[0].checks[0].expression.op='execute'}
        'check-column'{$p.tables[0].checks[0].expression.args[0].column='Missing'}
        'check-literal'{$p.tables[0].checks[0].expression.args[0].value=('x'*129)}
        'check-unicode'{$p.tables[0].checks[0].expression.args[0].value=[string][char]0x2019}
        'future-fk'{$p.tables=@($p.tables[1],$p.tables[0])}
        'fk-schema-case'{$p.tables[1].foreign_keys[0].schema=$p.tables[1].foreign_keys[0].schema.ToLowerInvariant()}
        'fk-table-case'{$p.tables[1].foreign_keys[0].table=$p.tables[1].foreign_keys[0].table.ToLowerInvariant()}
        'fk-arity'{$p.tables[0].foreign_keys[0].target_columns=@('IntentID')}
        'fk-no-target-key'{$p.tables[0].primary_key.columns=@('IntentID')}
        'fk-target-order'{$p.tables[1].foreign_keys[0].target_columns=@('GuildID','IntentID','HistoryVersion')}
        'fk-target-missing'{$p.tables[1].foreign_keys[0].target_columns=@('IntentID','GuildID','Missing')}
        'fk-target-type'{$p.tables[1].columns[0].type='int'}
        'fk-target-collation'{$p.tables[1].columns[1].collation='Latin1_General_CI_AS'}
        'fk-target-length'{$p.tables[1].columns[1].type='varchar(31)'}
        'constraint'{$p.tables[0].checks[0].name=$p.tables[0].primary_key.name}
        'version'{$p.version=2}
        'boolean-version'{$p.version=$true}
        'ledger'{$p.tables[0].schema='dbo';$p.tables[0].name='SchemaMigrationHistory'}
    }
    $raw=[Text.UTF8Encoding]::new($false).GetBytes(($p|ConvertTo-Json -Depth 20 -Compress))
    $path=Join-Path $root 'fixture.release.json';[IO.File]::WriteAllBytes($path,$raw)
    $hash=Get-K98ModuleHash $raw;if($damage -eq 'hash'){$hash='f'*64}
    $failed=$false
    try {$loaded=Read-K98ModuleProfile $path $hash $p.migration_id} catch {$failed=$true}
    if($failed -ne ($damage -ne 'none')){throw ('Table profile admission differs: '+$damage)}
    if(-not $failed -and ($loaded.Tables.Count -ne 2 -or $loaded.Tables[0].Create -notmatch '^CREATE TABLE \[KVK\]')){throw 'Generated table DDL differs'}
    $checks++
}
# Apostrophes are quoted as data, never treated as SQL syntax.
$p=[IO.File]::ReadAllText($FixturePath)|ConvertFrom-Json
$p.tables[0].checks[0].expression.args[0].value="x');DROP TABLE X;--"
. "$PSScriptRoot\SqlDeploy.TableRelease.ps1"
$loaded=Read-K98TableProfile $p
if(-not $loaded.Tables[0].Create.Contains("'x'');DROP TABLE X;--'")){throw 'Literal escaping differs'}
$checks++
# A declared unique key is also a valid new-table FK target, not only its PK.
$p=[IO.File]::ReadAllText($FixturePath)|ConvertFrom-Json
$originalKey=$p.tables[0].primary_key
$p.tables[0].primary_key=[pscustomobject]@{name='PK_TestAlternative';columns=@('IntentID')}
$p.tables[0].unique_keys=@($originalKey)
$loaded=Read-K98TableProfile $p
if($loaded.Tables[1].Create -notmatch 'FOREIGN KEY'){throw 'Declared unique target was not generated'}
$checks++
@{status='PASS';checks=$checks;sql_connected=$false;fixture=$root}|ConvertTo-Json -Compress
