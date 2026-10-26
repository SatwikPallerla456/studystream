#!/usr/bin/env python3
"""Run/build Tangerine with the project key embedded, without tracking it in Git.

Usage: python3 scripts/flutter_with_tvdb.py run -d macos --no-pub
       python3 scripts/flutter_with_tvdb.py build macos --release
FLUTTER_BIN may select a Flutter installation. Key values are never printed.
"""
import json
import os
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
source = root / '.env.tvdb.local'
if not source.exists():
    sys.exit('Missing .env.tvdb.local; supply THETVDB_API_KEY for this project build.')
values = {}
for line in source.read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        name, value = line.split('=', 1)
        values[name.strip()] = value.strip()
key = values.get('THETVDB_API_KEY', '')
if not key or any(c.isspace() for c in key) or len(key) > 4096:
    sys.exit('Invalid THETVDB_API_KEY in local build configuration.')
output = root / '.dart_tool' / 'tvdb-build.json'
output.parent.mkdir(exist_ok=True)
# Both files contain an extractable application key; keep local copies private.
fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as stream:
    json.dump({'THETVDB_API_KEY': key}, stream)
os.chmod(output, 0o600)
args = sys.argv[1:] or ['run', '-d', 'macos']
if args[0] not in {'run', 'build'}:
    sys.exit('This wrapper supports Flutter run and build only.')
os.chdir(root)
flutter = os.environ.get('FLUTTER_BIN', 'flutter')
os.execvp(flutter, [flutter, *args, f'--dart-define-from-file={output}'])
