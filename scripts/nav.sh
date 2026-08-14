#!/usr/bin/env bash
# Interactive / non-interactive stack CLI (go2_nav.py).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv

GO2_NAV="${REPO_ROOT}/goal_stop_judge/go2_nav.py"
if [[ ! -f "${GO2_NAV}" ]]; then
  echo "Missing ${GO2_NAV}. Run: make setup" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  exec python3 "${GO2_NAV}" "$@"
fi
exec python "${GO2_NAV}" "$@"
