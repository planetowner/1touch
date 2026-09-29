#!/usr/bin/env bash
set -euo pipefail
umask 077

transfer_directory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$transfer_directory/prepare-service-settings.sh"
prepare_service_settings "$transfer_directory" configure_calendar.py google_calendar_client.json \
  --client-json /input/google_calendar_client.json
echo 'Saved settings only. The database and running API have not been changed.'
echo "Server settings backup retained: $transfer_directory/before.env.production"
