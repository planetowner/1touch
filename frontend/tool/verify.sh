#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/.." && pwd)"
cd "$project_root"

dart format --output=none --set-exit-if-changed lib test
dart run tool/export_notification_messages.dart --check
dart run tool/export_verification_email_messages.dart --check
flutter analyze

if (($# > 0)); then
  flutter test "$@"
else
  flutter test
fi
