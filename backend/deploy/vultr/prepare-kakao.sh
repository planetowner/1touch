#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_kakao.py kakao.env --from-env /input/kakao.env

verify_saved_service_settings kakao
