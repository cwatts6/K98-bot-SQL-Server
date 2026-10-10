"""Reconstruct both finite repair forms from immutable reviewed migration bytes."""
import hashlib
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'migrations/20261010_002_stats_import_outcomes_encoding.sql').read_bytes()
assert hashlib.sha256(source).hexdigest() == '3792c37de9642cdb33579a4afec820f9d21a4eb14e8388281f3c40eed01c5aa9'
literals = [s.replace("''", "'") for s in re.findall(r"EXEC\s+sys\.sp_executesql\s+N'((?:[^']|'')*)'", source.decode('utf-8'))]
update = next(s for s in literals if s.startswith('ALTER PROCEDURE [dbo].[UPDATE_ALL2]')).replace('ALTER', 'CREATE', 1)
wrapper = next(s for s in literals if s.startswith('CREATE OR ALTER PROCEDURE dbo.usp_S11RunStatsImport')).replace('CREATE OR ALTER', 'CREATE  ', 1)
repair = (ROOT / 'migrations/20261010_003_stats_import_outcome_postimages.sql').read_text(encoding='utf-8')
for body in (update, wrapper):
    assert '\r' not in body
    for form in (body, body.replace('\n', '\r\n')):
        raw = form.encode('utf-16-le')
        assert '0x' + hashlib.sha256(raw).hexdigest() in repair
        assert str(len(raw)) in repair
print('PASS: exact LF and CRLF pre/postimages independently derived from reviewed migration; no SQL access.')
