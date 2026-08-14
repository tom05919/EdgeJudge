#!/usr/bin/env bash
# Robot-free smoke: stop_judge on examples/sample.png.
#
#   ./scripts/smoke_test.sh           # needs make weights
#   ./scripts/smoke_test.sh --imports # env / --help only
#   ./scripts/smoke_test.sh --edge    # also OmniVLA-edge --help in sim
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
    -h|--help) echo "Usage: scripts/smoke_test.sh [--imports] [--edge]"; exit 0 ;;
    *) echo "Unknown arg: ${arg}" >&2; exit 2 ;;
  esac
done

STOP_JUDGE="${REPO_ROOT}/goal_stop_judge/stop_judge.py"
SAMPLE="${REPO_ROOT}/examples/sample.png"
OUT_DIR="${REPO_ROOT}/examples/smoke_output"

edgejudge_init_conda
if ! edgejudge_conda_exists perception; then
  echo "conda env 'perception' not found. Run: make setup" >&2
  exit 1
fi

if [[ "${DO_JUDGE}" -eq 1 ]]; then
  ckpt="$(edgejudge_sam2_ckpt_path)"
  if [[ ! -s "${ckpt}" ]]; then
    echo "Missing SAM2 checkpoint: ${ckpt}" >&2
    echo "Run: make weights" >&2
    exit 1
  fi
  if [[ ! -f "${SAMPLE}" ]]; then
    echo "Missing ${SAMPLE}" >&2
    exit 1
  fi
  mkdir -p "${OUT_DIR}"
  echo "[smoke] stop_judge on ${SAMPLE} (prompt=${SMOKE_SAM_PROMPT})"
  edgejudge_in_conda_env perception python "${STOP_JUDGE}" \
    --image "${SAMPLE}" \
    --text-prompt "${SMOKE_SAM_PROMPT}" \
    --output-dir "${OUT_DIR}"
  echo "[smoke] visualizations in ${OUT_DIR}"
else
  echo "[smoke] perception: stop_judge.py --help + imports"
  edgejudge_in_conda_env perception python "${STOP_JUDGE}" --help >/dev/null
  edgejudge_in_conda_env perception python -c \
    "import numpy, torch, zmq, rclpy; from sensor_msgs.msg import Image; print('perception imports OK')"
fi

if [[ "${DO_EDGE}" -eq 1 ]]; then
  if ! edgejudge_conda_exists sim; then
    echo "conda env 'sim' not found. Run: make setup" >&2
    exit 1
  fi
  pth="${REPO_ROOT}/omni-VLA/omnivla-edge/omnivla-edge.pth"
  if [[ ! -s "${pth}" ]] || edgejudge_is_git_lfs_pointer "${pth}"; then
    echo "Missing omnivla-edge.pth. Run: make weights" >&2
    exit 1
  fi
  echo "[smoke] sim: run_omnivla_edge.py --help"
  edgejudge_in_conda_env sim bash -c \
    'cd "$1" && python inference/run_omnivla_edge.py --help >/dev/null' \
    bash "${REPO_ROOT}/omni-VLA"
fi

echo "[smoke] OK"
