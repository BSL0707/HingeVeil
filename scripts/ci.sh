#!/bin/sh
set -eu
VEIL_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$VEIL_ROOT"
python3 scripts/audit_publication.py
python3 scripts/check_source.py
python3 scripts/check_git_history.py
python3 -m unittest discover -s scripts -p 'test_*.py'
bash build.sh
python3 scripts/audit_publication.py --app Build/HingeVeil.app
python3 scripts/check_recovery_fixture.py
# CI intentionally does not start capture, poll the lid sensor, show windows,
# install the app, reset permissions, publish artifacts or contact payment APIs.
