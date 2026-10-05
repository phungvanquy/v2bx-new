#!/usr/bin/env bash
# Legacy entry point retained for previously installed V2bX managers.
echo 'Elise has moved to https://github.com/phungvanquy/elise' >&2
echo 'Install it there, then run: sudo elisectl migrate --from-v2bx --dry-run' >&2
echo 'Manage migrated nodes with elisectl. V2bX does not manage standalone Elise.' >&2
# Older V2bX uninstallers invoke this helper. Never uninstall standalone Elise.
[[ "${1:-}" == uninstall ]] && exit 0
exit 1
