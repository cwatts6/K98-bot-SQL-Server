# P02 D4b installed dependency source

The completed 10 November installed SQL inventory resolves two previously missing
definitions. This slice records their source contracts. It does not install them,
grant permissions, dispatch a backup or complete D4b's effective-permission gate.

## KS4 sequence

`sql_schema/dbo.KS4_UNO_SEQ.Sequence.sql` records the observed `int` sequence:
start 130489, increment 1, full signed-int range, no cycling and no cache. Its
current value is operational state and deliberately does not appear in the file.

This is reference material, like the other schema snapshots. D4c must require the
existing sequence and compare its structural properties before changing producers.
It must neither recreate nor restart it, derive its next value from a table maximum,
consume a value for discovery, nor restore an earlier observed current value.
Missing, exhausted or structurally different dependencies require investigation;
the initial declaration is not permission to repair an existing database.

## Fixed backup wrapper

`qualification/p02_d4/msdb_log_backup_wrapper.template.sql` records the observed
body with line endings normalized to LF and the private installed job UUID replaced by a named placeholder.
It is a qualification template, not an installed definition or migration. It runs
as the module owner and requests exactly one fixed SQL Agent job through
`msdb.dbo.sp_start_job`; it accepts no caller-selected job or SQL text.

The private inventory resolves that UUID to the existing enabled log-backup job.
D4c must bind the reviewed private UUID, authenticate the exact installed body,
owner and object permissions, and preserve the job, schedule and wrapper. A job
name match alone is insufficient. Never publish the raw private binding, silently
replace it with a fixture UUID, or create an absent wrapper from this template.

Native disposable tests compile the template under a new test database and inspect
its metadata and visible/denied object permissions. They never execute the wrapper
or `sp_start_job`. `EXECUTE AS OWNER` and a local EXECUTE grant do not establish
cross-database or SQL Agent permission on the installed server. D4b still owns
that effective capability check for each configured dispatch principal. A request
acknowledgement is not backup completion; uncertainty never authorizes fallback.

## Validation and remaining owners

`tests/test_p02_d4_installed_dependencies.py` uses a uniquely owned local K98DEV
database, with explicit opt-in and resource checks. It validates the actual sequence
metadata and checks wrapper body/owner plus allowed and denied fixture principals. All live
sequence, job, permission and backup state is outside the test target.

The SQL repository has a separate exact Changes review, Deep off. Bot commands,
application imports, provider flows and full business-data suites are unaffected.
Legacy retirement remains conditional on the outstanding caller checks. D4c owns
the combined migration and predecessor/postimage gates; D4d owns the protected
startup/updater transition; D5 and D6 retain qualification and deployment authority.
