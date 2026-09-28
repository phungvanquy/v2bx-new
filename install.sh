#!/bin/bash
# Keep the original one-click URL working after the installer moved to scripts/.
set -euo pipefail

installer=$(mktemp /tmp/v2bx-installer.XXXXXX)
trap 'rm -f "$installer"' EXIT

curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 --connect-timeout 15 \
    --output "$installer" \
    https://raw.githubusercontent.com/phungvanquy/v2bx-new/refs/heads/main/scripts/install.sh
bash -n "$installer"
bash "$installer" "$@"
