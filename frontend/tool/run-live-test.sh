#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
exec flutter run --debug --dart-define-from-file=tool/live-test.json "$@"
