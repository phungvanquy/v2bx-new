#!/bin/bash
# Keep the original one-click URL working after the installer moved to scripts/.
set -euo pipefail

installer=$(mktemp /tmp/v2bx-installer.XXXXXX)
trap 'rm -f "$installer"' EXIT
script_ref=${V2BX_SCRIPT_REF:-refs/heads/main}

curl --fail --location --silent --show-error \
    --retry 3 --retry-delay 2 --connect-timeout 15 \
    --output "$installer" \
    "https://raw.githubusercontent.com/phungvanquy/v2bx-new/${script_ref}/scripts/install.sh"
bash -n "$installer"
bash "$installer" "$@"
