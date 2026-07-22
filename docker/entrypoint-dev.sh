#!/bin/bash
set -euo pipefail
# Keep conda available in interactive and scripted shells.
if [[ -f /opt/miniforge3/etc/profile.d/conda.sh ]]; then
  # shellcheck source=/dev/null
  source /opt/miniforge3/etc/profile.d/conda.sh
fi
export GO2_CONDA_BASE="${GO2_CONDA_BASE:-/opt/miniforge3}"
cd /workspace 2>/dev/null || true
exec "$@"
