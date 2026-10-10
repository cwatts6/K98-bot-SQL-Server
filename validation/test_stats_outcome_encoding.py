"""Explicit local SQL rehearsal using the production PowerShell 5.1 file loader.

Creates one new synthetic database, never executes business procedures, and retains
the fixture READ_ONLY. Existing fixtures and production are never connected.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

import pyodbc

pyodbc.pooling = False
ROOT = Path(__file__).resolve().parents[1]
SERVER = r'lpc:localhost\K98DEV'
IDENTITY = r'9SX2VF4\K98DEV'
DATABASE = 'K98_S11_Encoding_20261010_r2'
OLD = '20261009_001_stats_import_outcomes'
FAILED = '20261010_001_stats_import_outcomes_collation'
NEW = '20261010_002_stats_import_outcomes_encoding'
PS = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

def connect(database):
    connection = pyodbc.connect(f'DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;', autocommit=True, timeout=5)
    connection.timeout = 30
    assert tuple(connection.execute("SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME()").fetchone()) == (IDENTITY,database)
    return connection

def execute(connection, text):
    cursor = connection.cursor()
    try:
        cursor.execute(text)
        while cursor.nextset():
            pass
    finally:
        cursor.close()

def definition_hash(text):
    text = re.sub(r'^(?:ALTER|CREATE OR ALTER)\b','CREATE',text.replace('\r\n','\n').strip(' \t\r\n'))
    return hashlib.sha256(text.encode('utf-16-le')).hexdigest()

def run():
    with tempfile.TemporaryDirectory(prefix='K98Encoding-') as temp:
        temp = Path(temp)
        export = temp / 'preimage.ps1'
        export.write_text(". '"+(ROOT/'deploy/StatsImportOutcome.Source.ps1').as_posix()+"'\n[IO.File]::WriteAllText('"+(temp/'source.sql').as_posix()+"',(Get-S11PreOutcomeSource ([IO.File]::ReadAllText('"+(ROOT/'sql_schema/dbo.UPDATE_ALL2.StoredProcedure.sql').as_posix()+"'))),[Text.UTF8Encoding]::new($false))",encoding='utf-8')
        subprocess.run([PS,'-NoProfile','-NonInteractive','-File',str(export)],check=True,capture_output=True)
        canonical = (temp/'source.sql').read_text(encoding='utf-8')
        canonical = canonical[re.search(r'(?m)^(?:ALTER|CREATE OR ALTER) PROCEDURE',canonical).start():].strip()
        legacy = canonical.encode('utf-8').decode('cp1252')
        assert definition_hash(legacy) == 'cbe4077f8f1f2f92bccede963f19919665f4fcefe63def90fd834bf92a723cc9'
        c = connect('master')
        try:
            assert c.execute('SELECT COUNT(*) FROM sys.databases WHERE name=?',DATABASE).fetchval() == 0, 'Preserve existing fixture'
            execute(c,f'CREATE DATABASE [{DATABASE}] COLLATE Latin1_General_CI_AS;')
        finally:
            c.close()
        c = connect(DATABASE)
        try:
            execute(c,'CREATE SCHEMA KVK')
            execute(c,'CREATE ROLE ExportLegacyEntryReader')
            execute(c,'CREATE TABLE dbo.ExportJob(JobID uniqueidentifier PRIMARY KEY); CREATE TABLE dbo.ExportJobResource(JobID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(JobID,ResourceKey)); CREATE TABLE KVK.SourceOutputOperationResource(OperationID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(OperationID,ResourceKey)); CREATE TABLE dbo.ExportExecutionSession(State varchar(32) NOT NULL)')
            execute(c,(ROOT/'sql_schema/dbo.ExportPreparation.Table.sql').read_text(encoding='utf-8-sig'))
            resource = (ROOT/'sql_schema/dbo.ExportResource.Table.sql').read_text(encoding='utf-8-sig')
            constraints = re.findall(r'(?m)^ALTER TABLE.*;',resource)
            execute(c,re.sub(r'(?m)^ALTER TABLE.*;','',resource))
            execute(c,(ROOT/'sql_schema/dbo.ExportPreparationResource.Table.sql').read_text(encoding='utf-8-sig'))
            for constraint in constraints:
                execute(c,constraint)
            execute(c,re.sub(r'^(?:ALTER|CREATE OR ALTER) PROCEDURE','CREATE PROCEDURE',legacy))
            execute(c,(ROOT/'sql_schema/dbo.SchemaMigrationHistory.Table.sql').read_text(encoding='utf-8-sig'))
            for name,digest in [(OLD,'344f050165a7f64078615db9deac10a687babdc1c28c2536eaedcda07fae87f3'),(FAILED,'e423e79fd13234b91b62336ab8e34ff2b018b2bffcdfb3cd53dec1a9342ef315')]:
                c.execute("INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,Status,ErrorMessage) VALUES(?,?,?,SYSUTCDATETIME(),N'Failed',N'Synthetic retained failure')",name,name+'.sql',digest)
            retained = [tuple(row) for row in c.execute('SELECT * FROM dbo.SchemaMigrationHistory ORDER BY MigrationId').fetchall()]
        finally:
            c.close()
        def apply(name, corrupt=False):
            text = (ROOT/'migrations'/f'{name}.sql').read_text(encoding='utf-8-sig').replace("<> N'ROK_TRACKER'",f"<> N'{DATABASE}'")
            if corrupt:
                text = text.encode('utf-8').decode('cp1252')
            file = temp/'migration.sql'
            file.write_bytes(text.encode('utf-8'))
            harness = temp/'apply.ps1'
            harness.write_text("$ErrorActionPreference='Stop'\n. '"+(ROOT/'deploy/SqlDeploy.Common.ps1').as_posix()+"'\nInvoke-K98SqlFileWithSqlClient -ServerName '"+SERVER+"' -DatabaseName '"+DATABASE+"' -InputFile '"+file.as_posix()+"' -QueryTimeout 30\n",encoding='utf-8')
            return subprocess.run([PS,'-NoProfile','-NonInteractive','-File',str(harness)],capture_output=True,timeout=60)
        old = apply(FAILED)
        assert old.returncode != 0 and b'UPDATE_ALL2 source differs' in old.stderr, old.stderr
        c = connect(DATABASE)
        try:
            assert tuple(c.execute("SELECT OBJECT_ID(N'dbo.StatsImportExecution'),OBJECT_ID(N'dbo.usp_S11RunStatsImport')").fetchone()) == (None,None)
        finally:
            c.close()
        corrupt = apply(NEW,corrupt=True)
        assert corrupt.returncode != 0 and b'Installed UPDATE_ALL2 source differs' in b' '.join(corrupt.stderr.split()), corrupt.stderr
        c = connect(DATABASE)
        try:
            assert tuple(c.execute("SELECT OBJECT_ID(N'dbo.StatsImportExecution'),OBJECT_ID(N'dbo.usp_S11RunStatsImport')").fetchone()) == (None,None)
            assert definition_hash(c.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2'))").fetchval()) == 'cbe4077f8f1f2f92bccede963f19919665f4fcefe63def90fd834bf92a723cc9'
        finally:
            c.close()
        for attempt in range(2):
            result = apply(NEW)
            assert result.returncode == 0, result.stderr.decode(errors='replace')
        c = connect(DATABASE)
        try:
            actual = {}
            for name,expected in [('UPDATE_ALL2','4a5640dbdf811d645ba9ed83062f08408f5d02e6c9c2338585042b031af080bc'),('usp_S11RunStatsImport','034ca049c92a8b8ea654edca21f03269afae4884d398ea7d26e7ab0aade0b81e')]:
                actual[name] = definition_hash(c.execute('SELECT OBJECT_DEFINITION(OBJECT_ID(?))','dbo.'+name).fetchval())
                assert actual[name] == expected
            assert [tuple(row) for row in c.execute('SELECT * FROM dbo.SchemaMigrationHistory ORDER BY MigrationId').fetchall()] == retained
            assert c.execute('SELECT COUNT(*) FROM dbo.StatsImportExecution').fetchval() == 0
        finally:
            c.close()
        c = connect('master')
        try:
            execute(c,f'ALTER DATABASE [{DATABASE}] SET READ_ONLY WITH NO_WAIT;')
            assert c.execute('SELECT is_read_only FROM sys.databases WHERE name=?',DATABASE).fetchval() == 1
        finally:
            c.close()
    return dict(status='PASS',database=DATABASE,legacy_preimage_failure_reproduced=True,corrupt_postimage_rejected_and_rolled_back=True,actual_powershell51_sqlclient_loader=True,corrected_installation_and_repeat=True,postimage_hashes=actual,both_failed_receipts_unchanged=True,business_work_executed=False,retained_read_only=True,limitation='Exercises the exact migration file loader and SQL transaction; not the outer backup/Git/ledger orchestration runner.')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.execute:
        result=run()
        args.output.write_text(json.dumps(result,indent=2),encoding='utf-8')
        print(json.dumps(result))
    else:
        print(json.dumps(dict(server=SERVER,database=DATABASE,action='New synthetic fixture, exact legacy preimage, failed/corrupt/corrected migration checks via PowerShell5.1 loader, preserve both failed receipts, retain READ_ONLY; no business execution.')))
