#!/usr/bin/env bash
# Bootstrap EdgeJudge code deps, conda envs, and the Go2 SDK.
#
#   ./scripts/bootstrap.sh           # --all (code + sim/perception envs + sdk)
#   ./scripts/bootstrap.sh --code    # submodules, UniDepth, Grounded-SAM-2, shim
#   ./scripts/bootstrap.sh --envs    # sim + perception (add --full for omnivla)
#   ./scripts/bootstrap.sh --sdk     # colcon build go2_interfaces + go2_robot_sdk
#   ./scripts/bootstrap.sh --all --full
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv
edgejudge_load_pins

DO_CODE=0
DO_ENVS=0
DO_SDK=0
DO_FULL=0
HAVE_STAGE=0

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap.sh [--code] [--envs] [--sdk] [--full] [--all]

  --code   Submodules, UniDepth, Grounded-SAM-2, omni-VLA/OmniVLA -> . shim
  --envs   conda envs sim + perception (existing env is left as-is)
  --sdk    colcon build go2_interfaces + go2_robot_sdk (needs sim)
  --full   With --envs, also create the omnivla env
  --all    --code --envs --sdk (default if no stage flag is given)

Weights are separate: make weights / scripts/download_weights.sh
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --code) DO_CODE=1; HAVE_STAGE=1 ;;
    --envs) DO_ENVS=1; HAVE_STAGE=1 ;;
    --sdk) DO_SDK=1; HAVE_STAGE=1 ;;
    --full) DO_FULL=1 ;;
    --all) DO_CODE=1; DO_ENVS=1; DO_SDK=1; HAVE_STAGE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: ${arg}" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${HAVE_STAGE}" -eq 0 ]]; then
  DO_CODE=1
  DO_ENVS=1
  DO_SDK=1
fi

bootstrap_code() {
  echo "[bootstrap] Initializing git submodules"
  git -C "${REPO_ROOT}" submodule update --init --recursive

  if [[ ! -f "${REPO_ROOT}/goal_stop_judge/go2_nav.py" || \
        ! -f "${REPO_ROOT}/goal_stop_judge/envs/install_sim_env.sh" ]]; then
    echo "goal_stop_judge is missing go2_nav.py / envs/. Expected ${GOAL_STOP_JUDGE_SHA}." >&2
    exit 1
  fi

  edgejudge_clone_pinned "${UNIDEPTH_URL}" \
    "${REPO_ROOT}/goal_stop_judge/depth_implementation/UniDepth" \
    "${UNIDEPTH_SHA}" "UniDepth"
  edgejudge_clone_pinned "${GROUNDED_SAM_URL}" \
    "${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2" \
    "${GROUNDED_SAM_SHA}" "Grounded-SAM-2"
  edgejudge_ensure_omnivla_shim
}

bootstrap_envs() {
  local install_dir="${REPO_ROOT}/goal_stop_judge/envs"
  if [[ ! -f "${install_dir}/install_sim_env.sh" ]]; then
    echo "Missing ${install_dir}/install_sim_env.sh — run --code first." >&2
    exit 1
  fi
  edgejudge_ensure_omnivla_shim
  edgejudge_init_conda

  echo "[bootstrap] conda env sim"
  bash "${install_dir}/install_sim_env.sh"
  echo "[bootstrap] conda env perception"
  bash "${install_dir}/install_perception_env.sh"
  if [[ "${DO_FULL}" -eq 1 ]]; then
    echo "[bootstrap] conda env omnivla"
    bash "${install_dir}/install_omnivla_env.sh"
  else
    echo "[bootstrap] Skipping omnivla env. Pass --full for local/remote full OmniVLA."
  fi
}

bootstrap_sdk() {
  local ws="${REPO_ROOT}/unofficial_sdk_unitree_go_2"
  if [[ ! -d "${ws}/src/go2_robot_sdk" || ! -d "${ws}/src/go2_interfaces" ]]; then
    echo "Missing go2_robot_sdk / go2_interfaces under ${ws}/src — run --code first." >&2
    exit 1
  fi
  edgejudge_init_conda
  if ! edgejudge_conda_exists sim; then
    echo "conda env 'sim' not found. Run: ./scripts/bootstrap.sh --envs" >&2
    exit 1
  fi

  echo "[bootstrap] colcon build (go2_interfaces go2_robot_sdk)"
  edgejudge_in_conda_env sim bash -c 'cd "$1" && colcon build --packages-select go2_interfaces go2_robot_sdk' \
    bash "${ws}"
}

echo "[bootstrap] repo: ${REPO_ROOT}"
[[ "${DO_CODE}" -eq 1 ]] && bootstrap_code
[[ "${DO_ENVS}" -eq 1 ]] && bootstrap_envs
[[ "${DO_SDK}" -eq 1 ]] && bootstrap_sdk
echo "[bootstrap] Done."
