#!/usr/bin/env bash
# Robot-free smoke test: perception imports, then stop_judge on examples/sample.png.
#
#   ./scripts/smoke_test.sh           # imports + judge (needs make weights)
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

edgejudge_init_conda

if ! edgejudge_conda_exists perception; then
  echo "conda env 'perception' not found. Run: make setup" >&2
  exit 1
fi

run_in_env() {
  local env_name="$1"
  shift
  (
    set +u
    conda activate "${env_name}"
    set -u
    "$@"
  )
}

echo "[smoke] perception: stop_judge.py --help"
run_in_env perception python "${STOP_JUDGE}" --help >/dev/null

echo "[smoke] perception: core imports"
run_in_env perception python -c \
  "import numpy, torch, zmq, rclpy; from sensor_msgs.msg import Image; print('perception imports OK')"

if [[ "${DO_JUDGE}" -eq 1 ]]; then
  ckpt="$(edgejudge_sam2_ckpt_path)"
  if [[ ! -f "${ckpt}" ]]; then
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
  run_in_env perception python "${STOP_JUDGE}" \
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
  echo "[smoke] sim: run_omnivla_edge.py --help"
  run_in_env sim python "${EDGE_SCRIPT}" --help >/dev/null
fi

echo "[smoke] OK"
