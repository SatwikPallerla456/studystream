#!/usr/bin/env python3
"""Run native acceptance with a synthetic fixture embedded only in the test build."""
import base64
import json
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tangerine-verification-') as temporary:
    defines = Path(temporary) / 'defines.json'
    defines.write_text(json.dumps({
        'TANGERINE_VIDEO_FIXTURE_BASE64': base64.b64encode(
            (root / 'test/fixtures/motion.mp4').read_bytes()).decode(),
        'STUDYSTREAM_DATA_DIR': str(Path(temporary) / 'data'),
    }))
    raise SystemExit(subprocess.call([
        'flutter', 'test', 'integration_test/library_flow_test.dart', '-d', 'macos',
        '--no-pub', f'--dart-define-from-file={defines}',
    ], cwd=root))
