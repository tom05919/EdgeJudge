#!/usr/bin/env bash
# Robot-free smoke test: perception imports, then stop_judge on examples/sample.png.
#
#   ./scripts/smoke_test.sh           # imports + judge (needs make weights)
#   ./scripts/smoke_test.sh --imports # env / --help only
#   ./scripts/smoke_test.sh --edge    # also OmniVLA-edge import/--help in sim
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv
edgejudge_load_pins

DO_JUDGE=1
DO_EDGE=0

for arg in "$@"; do
  case "${arg}" in
    --imports) DO_JUDGE=0 ;;
    --edge) DO_EDGE=1 ;;
    -h|--help)
      echo "Usage: scripts/smoke_test.sh [--imports] [--edge]"
      exit 0
      ;;
    *) echo "Unknown arg: ${arg}" >&2; exit 2 ;;
  esac
done

SAMPLE="${REPO_ROOT}/examples/sample.png"
OUT_DIR="${REPO_ROOT}/examples/smoke_output"
STOP_JUDGE="${REPO_ROOT}/goal_stop_judge/stop_judge.py"
EDGE_SCRIPT="${REPO_ROOT}/omni-VLA/inference/run_omnivla_edge.py"
WEIGHTS_HINT="Run: make weights"

edgejudge_init_conda

if ! edgejudge_conda_exists perception; then
  echo "conda env 'perception' not found. Run: make setup" >&2
  exit 1
fi

echo "[smoke] perception: stop_judge.py --help"
edgejudge_in_conda_env perception python "${STOP_JUDGE}" --help >/dev/null

echo "[smoke] perception: core imports"
edgejudge_in_conda_env perception python -c \
  "import numpy, torch, zmq, rclpy; from sensor_msgs.msg import Image; print('perception imports OK')"

if [[ "${DO_JUDGE}" -eq 1 ]]; then
  edgejudge_require_blob "$(edgejudge_sam2_ckpt_path)" "${WEIGHTS_HINT}"
  edgejudge_require_file "${SAMPLE}" "Missing bundled smoke image. See examples/README.md."

  echo "[smoke] Hugging Face snapshots (Grounding DINO + UniDepth, local_files_only)"
  if ! edgejudge_in_conda_env perception python -c "
from huggingface_hub import snapshot_download
import sys
missing = []
for repo in ('${GROUNDING_DINO_MODEL}', '${UNIDEPTH_HF_MODEL}'):
    try:
        snapshot_download(repo, local_files_only=True)
    except Exception:
        missing.append(repo)
if missing:
    print('Missing Hugging Face cache:', ', '.join(missing), file=sys.stderr)
    print('Run: make weights   (or huggingface-cli download <repo> in the perception env)', file=sys.stderr)
    sys.exit(1)
print('HF cache OK')
"; then
    exit 1
  fi

  mkdir -p "${OUT_DIR}"
  echo "[smoke] stop_judge on ${SAMPLE} (prompt=${SMOKE_SAM_PROMPT})"
  edgejudge_in_conda_env perception python "${STOP_JUDGE}" \
    --image "${SAMPLE}" \
    --text-prompt "${SMOKE_SAM_PROMPT}" \
    --output-dir "${OUT_DIR}"
  echo "[smoke] visualizations in ${OUT_DIR}"
fi

if [[ "${DO_EDGE}" -eq 1 ]]; then
  if ! edgejudge_conda_exists sim; then
    echo "conda env 'sim' not found. Run: make setup" >&2
    exit 1
  fi
  if [[ ! -f "${EDGE_SCRIPT}" ]]; then
    echo "Missing ${EDGE_SCRIPT}. Run: make setup" >&2
    exit 1
  fi
  # --help returns before load_model, so also require the cwd-relative weight file.
  edgejudge_require_blob \
    "${REPO_ROOT}/omni-VLA/omnivla-edge/omnivla-edge.pth" \
    "${WEIGHTS_HINT} (run_omnivla_edge.py loads ./omnivla-edge/omnivla-edge.pth from omni-VLA/)."
  echo "[smoke] sim: run_omnivla_edge.py --help (imports + argparse; does not load CUDA weights)"
  edgejudge_in_conda_env sim bash -c '
    set -euo pipefail
    cd "$1"
    python inference/run_omnivla_edge.py --help >/dev/null
  ' bash "${REPO_ROOT}/omni-VLA"
fi

echo "[smoke] OK"
