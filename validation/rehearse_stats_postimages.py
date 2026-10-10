"""Explicit new local SQL fixture: repair -> exact R4 metadata comparison.

No production access, procedure execution, existing-fixture writes or receipt
edits. Uses exact procedure bodies from reviewed migration, not production data.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
import pyodbc

ROOT = Path(__file__).resolve().parents[1]
SERVER = r'lpc:localhost\K98DEV'
DATABASE = 'K98_S11_Postimages_20261010_outer_r1'
PS = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
MIGRATION = '20261010_003_stats_import_outcome_postimages'
pyodbc.pooling = False

def connect(database):
    c = pyodbc.connect(f'DRIVER={{ODBC Driver 18 for SQL Server}};SERVER={SERVER};DATABASE={database};Trusted_Connection=yes;Encrypt=yes;TrustServerCertificate=yes;', autocommit=True, timeout=5)
    c.timeout = 30
    assert tuple(c.execute("SELECT CONVERT(nvarchar(128),SERVERPROPERTY('ServerName')),DB_NAME()").fetchone()) == (r'9SX2VF4\K98DEV', database)
    return c

def execute(c, sql):
    cursor = c.cursor()
    try:
        cursor.execute(sql)
        while cursor.nextset():
            pass
    finally:
        cursor.close()

def run_outer(output):
    checkout = output.parent / 'postimage-outer-checkout'
    assert not checkout.exists(), 'Preserve prior runner checkout'
    checkout.mkdir()
    archive = output.parent / 'postimage-outer-source.zip'
    assert not archive.exists()
    def git(*args, cwd=checkout):
        return subprocess.check_output(['git', *args], cwd=cwd)
    assert not git('status', '--porcelain', '--untracked-files=no', cwd=ROOT).strip(), 'Commit reviewed candidate before outer rehearsal'
    git('archive', '--format=zip', '--output=' + str(archive), 'HEAD', cwd=ROOT)
    with zipfile.ZipFile(archive) as z:
        assert all(not n.startswith(('/', '\\')) and '..' not in Path(n).parts for n in z.namelist())
        z.extractall(checkout)
    migration = checkout / 'migrations' / (MIGRATION + '.sql')
    raw = migration.read_bytes()
    assert raw.count(b"<> N'ROK_TRACKER'") == 1
    migration.write_bytes(raw.replace(b"<> N'ROK_TRACKER'", f"<> N'{DATABASE}'".encode()))
    git('init', '-b', 'main')
    git('config', 'core.autocrlf', 'false')
    git('config', 'user.name', 'K98 local rehearsal')
    git('config', 'user.email', 'rehearsal@localhost')
    git('add', '.')
    git('commit', '-m', 'Local fixture: reviewed candidate with exact database guard substitution')
    c = connect(DATABASE)
    try:
        execute(c, (ROOT / 'sql_schema/dbo.DeploymentRunHistory.Table.sql').read_text(encoding='utf-8-sig'))
        backup_dir = Path(c.execute("SELECT CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'))").fetchval())
        full = backup_dir / (DATABASE + '.bak')
        log = backup_dir / (DATABASE + '.trn')
        assert not full.exists() and not log.exists()
        execute(c, f'ALTER DATABASE [{DATABASE}] SET RECOVERY FULL;')
        execute(c, f"BACKUP DATABASE [{DATABASE}] TO DISK=N'{str(full).replace(chr(39),chr(39)*2)}' WITH CHECKSUM;")
        execute(c, f"BACKUP LOG [{DATABASE}] TO DISK=N'{str(log).replace(chr(39),chr(39)*2)}' WITH CHECKSUM;")
    finally:
        c.close()
    env = dict(os.environ, PATH=r'C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\cmd', PSModulePath=r'C:\Windows\System32\WindowsPowerShell\v1.0\Modules')
    for attempt in range(2):
        result = subprocess.run([PS, '-NoProfile', '-NonInteractive', '-File', str(checkout / 'deploy/Deploy-SqlMigration.ps1'), '-ServerName', SERVER, '-DatabaseName', DATABASE, '-RepoPath', str(checkout), '-MigrationId', MIGRATION], capture_output=True, timeout=180, env=env)
        output.with_name('postimage-outer-' + str(attempt) + '.stdout.txt').write_bytes(result.stdout)
        output.with_name('postimage-outer-' + str(attempt) + '.stderr.txt').write_bytes(result.stderr)
        assert result.returncode == 0, result.stderr.decode(errors='replace')
        assert b'Applied migration count: ' + str(1 if attempt == 0 else 0).encode() in result.stdout
    c = connect(DATABASE)
    try:
        assert tuple(c.execute('SELECT Status,ChecksumSha256 FROM dbo.SchemaMigrationHistory WHERE MigrationId=?', MIGRATION).fetchone()) == ('Applied', hashlib.sha256(migration.read_bytes()).hexdigest())
    finally:
        c.close()

def run(packet, output, outer):
    assert not output.exists(), 'Retain previous rehearsal evidence'
    source = (ROOT / 'migrations/20261010_002_stats_import_outcomes_encoding.sql').read_bytes()
    assert hashlib.sha256(source).hexdigest() == '3792c37de9642cdb33579a4afec820f9d21a4eb14e8388281f3c40eed01c5aa9'
    literals = [s.replace("''", "'") for s in re.findall(r"EXEC\s+sys\.sp_executesql\s+N'((?:[^']|'')*)'", source.decode('utf-8'))]
    bodies = {
        'dbo.UPDATE_ALL2': next(s for s in literals if s.startswith('ALTER PROCEDURE [dbo].[UPDATE_ALL2]')).replace('ALTER', 'CREATE', 1),
        'dbo.usp_S11RunStatsImport': next(s for s in literals if s.startswith('CREATE OR ALTER PROCEDURE dbo.usp_S11RunStatsImport')).replace('CREATE OR ALTER', 'CREATE  ', 1),
    }
    spec = importlib.util.spec_from_file_location('r4_probe', packet / 'Check-OutcomeSql.py')
    probe = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(probe)
    bank = json.loads((packet / 'sql-query-bank.json').read_bytes())
    def compare(c):
        result = {}
        for kind, key in [('application', 'metadata.objects'), ('legacy', 'modules')]:
            command = next(q for q in bank['after'][kind] if q['name'] == key)
            cursor = c.execute(command['query'], json.dumps(list(bodies)))
            actual = [dict(zip([col[0] for col in cursor.description], row)) for row in cursor.fetchall()]
            expected = json.loads((packet / ('after-' + kind + '.json')).read_bytes())
            for part in key.split('.'):
                expected = expected[part]
            expected = [r for r in expected if r['ObjectName'] in bodies]
            result[kind] = probe.differences(expected, actual)
        return result
    c = connect('master')
    try:
        assert c.execute('SELECT COUNT(*) FROM sys.databases WHERE name=?', DATABASE).fetchval() == 0
        execute(c, f'CREATE DATABASE [{DATABASE}] COLLATE Latin1_General_CI_AS;')
    finally:
        c.close()
    try:
        c = connect(DATABASE)
        try:
            execute(c, 'SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;')
            execute(c, 'CREATE SCHEMA KVK;')
            execute(c, 'CREATE TABLE dbo.ExportExecutionSession(State varchar(32) NOT NULL);')
            execute(c, 'CREATE TABLE dbo.ExportJob(JobID uniqueidentifier PRIMARY KEY); CREATE TABLE dbo.ExportJobResource(JobID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(JobID,ResourceKey)); CREATE TABLE KVK.SourceOutputOperationResource(OperationID uniqueidentifier NOT NULL,ResourceKey varchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL,PRIMARY KEY(OperationID,ResourceKey));')
            execute(c, (ROOT / 'sql_schema/dbo.ExportPreparation.Table.sql').read_text(encoding='utf-8-sig'))
            resource = (ROOT / 'sql_schema/dbo.ExportResource.Table.sql').read_text(encoding='utf-8-sig')
            constraints = re.findall(r'(?m)^ALTER TABLE.*;', resource)
            execute(c, re.sub(r'(?m)^ALTER TABLE.*;', '', resource))
            execute(c, (ROOT / 'sql_schema/dbo.ExportPreparationResource.Table.sql').read_text(encoding='utf-8-sig'))
            for constraint in constraints:
                execute(c, constraint)
            execute(c, (ROOT / 'sql_schema/dbo.StatsImportExecution.Table.sql').read_text(encoding='utf-8-sig'))
            execute(c, (ROOT / 'sql_schema/dbo.SchemaMigrationHistory.Table.sql').read_text(encoding='utf-8-sig'))
            for name, status, digest in [
                ('20261009_001_stats_import_outcomes', 'Failed', '344f050165a7f64078615db9deac10a687babdc1c28c2536eaedcda07fae87f3'),
                ('20261010_001_stats_import_outcomes_collation', 'Failed', 'e423e79fd13234b91b62336ab8e34ff2b018b2bffcdfb3cd53dec1a9342ef315'),
                ('20261010_002_stats_import_outcomes_encoding', 'Applied', hashlib.sha256(source).hexdigest()),
            ]:
                c.execute('INSERT dbo.SchemaMigrationHistory(MigrationId,MigrationFile,ChecksumSha256,AppliedAtUtc,Status) VALUES(?,?,?,SYSUTCDATETIME(),?)', name, name + '.sql', digest, status)
            for body in bodies.values():
                execute(c, body.replace('\n', '\r\n'))
            execute(c, 'CREATE USER FixtureReader WITHOUT LOGIN; GRANT EXECUTE ON dbo.UPDATE_ALL2 TO FixtureReader; GRANT VIEW DEFINITION ON dbo.usp_S11RunStatsImport TO FixtureReader;')
            retained = [tuple(r) for r in c.execute('SELECT * FROM dbo.SchemaMigrationHistory ORDER BY MigrationId')]
            before = compare(c)
            assert all(len(v) == 1 and v[0]['removed'] == v[0]['added'] == 2 for v in before.values()), before
        finally:
            c.close()
        with tempfile.TemporaryDirectory(prefix='K98Postimages-') as directory:
            folder = Path(directory)
            text = (ROOT / 'migrations' / (MIGRATION + '.sql')).read_text(encoding='utf-8')
            assert text.count("<> N'ROK_TRACKER'") == 1
            text = text.replace("<> N'ROK_TRACKER'", f"<> N'{DATABASE}'")
            sql = folder / 'repair.sql'
            sql.write_bytes(text.encode('utf-8'))
            harness = folder / 'apply.ps1'
            harness.write_text("$ErrorActionPreference='Stop'\n. '" + (ROOT / 'deploy/SqlDeploy.Common.ps1').as_posix() + "'\nInvoke-K98SqlFileWithSqlClient -ServerName '" + SERVER + "' -DatabaseName '" + DATABASE + "' -InputFile '" + sql.as_posix() + "' -QueryTimeout 30\n", encoding='utf-8')
            def apply():
                return subprocess.run([PS, '-NoProfile', '-NonInteractive', '-File', str(harness)], capture_output=True, timeout=60)
            c = connect(DATABASE)
            try:
                altered = bodies['dbo.usp_S11RunStatsImport'].replace('CREATE', 'ALTER', 1).replace('\n', '\r\n') + '\r\n-- unreviewed drift'
                execute(c, altered)
            finally:
                c.close()
            bad = apply()
            assert bad.returncode != 0 and b'procedure body or SET context differs' in b' '.join(bad.stderr.split()), bad.stderr
            c = connect(DATABASE)
            try:
                assert c.execute("SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.UPDATE_ALL2'))").fetchval() == bodies['dbo.UPDATE_ALL2'].replace('\n', '\r\n')
                execute(c, bodies['dbo.usp_S11RunStatsImport'].replace('CREATE', 'ALTER', 1).replace('\n', '\r\n'))
                c.execute("INSERT dbo.ExportExecutionSession VALUES('running')")
            finally:
                c.close()
            active = apply()
            assert active.returncode != 0 and b'Execution sessions must be closed' in b' '.join(active.stderr.split()), active.stderr.decode(errors='replace')
            c = connect(DATABASE)
            try:
                c.execute('DELETE dbo.ExportExecutionSession')
            finally:
                c.close()
            assert text.count('    COMMIT;') == 1
            sql.write_bytes(text.replace('    COMMIT;', "    THROW 51960, 'Synthetic postcondition interruption', 1;\n    COMMIT;").encode('utf-8'))
            rollback = apply()
            assert rollback.returncode != 0 and b'Synthetic postcondition interruption' in b' '.join(rollback.stderr.split()), rollback.stderr
            c = connect(DATABASE)
            try:
                assert compare(c) == before, 'Failed transaction must leave both exact CRLF bodies'
            finally:
                c.close()
            sql.write_bytes(text.encode('utf-8'))
            if outer:
                run_outer(output)
            else:
                success = apply()
                assert success.returncode == 0, success.stderr.decode(errors='replace')
                repeat = apply()
                assert repeat.returncode == 0, repeat.stderr.decode(errors='replace')
        c = connect(DATABASE)
        try:
            after = compare(c)
            assert after == {'application': [], 'legacy': []}, after
            assert [tuple(r) for r in c.execute('SELECT * FROM dbo.SchemaMigrationHistory WHERE MigrationId<>? ORDER BY MigrationId', MIGRATION)] == retained
            raw_hashes = {name: hashlib.sha256(c.execute('SELECT OBJECT_DEFINITION(OBJECT_ID(?))', name).fetchval().encode('utf-16-le')).hexdigest() for name in bodies}
            result = dict(status='PASS', database=DATABASE, exact_r4_comparison_before=before, exact_r4_comparison_after=after, raw_postimage_hashes=raw_hashes, all_predecessor_receipts_unchanged=True, drift_refused_before_either_alter=True, active_session_refused=True, both_bodies_rolled_back_on_postcondition_failure=True, repeated_repair_verified=True, outer_backup_git_ledger_runner=outer, business_work_executed=False)
        finally:
            c.close()
    finally:
        c = connect('master')
        try:
            execute(c, f'ALTER DATABASE [{DATABASE}] SET READ_ONLY WITH NO_WAIT;')
        finally:
            c.close()
    result['retained_read_only'] = True
    output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result))

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--execute', action='store_true', required=True)
    p.add_argument('--packet', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--outer', action='store_true')
    a = p.parse_args()
    run(a.packet, a.output, a.outer)
