#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/.." && pwd)"
cd "$project_root"

dart format --output=none --set-exit-if-changed lib test
dart run tool/export_notification_messages.dart --check
dart run tool/export_verification_email_messages.dart --check
python3 tool/export_legal_documents.py --check
flutter analyze

# 위젯 테스트의 HTTP 요청은 모의 클라이언트가 처리해요. 실행에 필요한 주소만 지정해요.
flutter test --dart-define=API_BASE_URI=https://example.com/v1/ "$@"
