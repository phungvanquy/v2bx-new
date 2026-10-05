#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$root" <<'PY'
from pathlib import Path
from tempfile import TemporaryDirectory
import os
import subprocess
import sys

root = Path(sys.argv[1])
with TemporaryDirectory() as directory:
    directory = Path(directory)
    sentinel = directory / 'legacy-helper'
    sentinel.write_text('#!/bin/sh\necho "legacy Elise was touched" >&2\nexit 99\n')
    sentinel.chmod(0o755)
    manager = (root / 'scripts/V2bX.sh').read_text()
    start = manager.index('uninstall() {')
    end = manager.index('\nstart() {', start)
    uninstall = manager[start:end].replace('/usr/bin/V2bX-elise', str(sentinel))
    command = uninstall + '''
confirm() { return 0; }
systemctl() { printf 'systemctl %s\\n' "$*"; }
rm() { printf 'rm %s\\n' "$*"; }
before_show_menu() { :; }
uninstall test
'''
    result = subprocess.run(['bash', '-c', command], check=True, capture_output=True, text=True)
    assert 'legacy Elise was touched' not in result.stderr
    assert 'systemctl stop V2bX' in result.stdout
    assert all('elise' not in line.lower() for line in result.stdout.splitlines() if line.startswith(('rm ', 'systemctl ')))
    assert sentinel.exists()

for script in ('scripts/install.sh', 'scripts/V2bX.sh', 'scripts/elise.sh'):
    result = subprocess.run(['bash', str(root / script), 'elise'], capture_output=True, text=True)
    assert result.returncode != 0
    assert 'https://github.com/phungvanquy/elise' in result.stderr
    assert 'migrate --from-v2bx' in result.stderr

# Old cached V2bX managers call the retired helper during uninstallation.
result = subprocess.run(['bash', str(root / 'scripts/elise.sh'), 'uninstall'], capture_output=True, text=True)
assert result.returncode == 0
print('V2bX separation checks passed')
PY
