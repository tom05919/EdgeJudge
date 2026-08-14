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

  --code   Init git submodules; clone UniDepth + Grounded-SAM-2 at pinned SHAs;
           create omni-VLA/OmniVLA -> . so install_*_env.sh can find the tree.
  --envs   Create conda envs sim and perception (requires --code first).
  --sdk    colcon build go2_interfaces + go2_robot_sdk inside unofficial_sdk_unitree_go_2
           (requires sim env).
  --full   With --envs, also create the omnivla env (full / remote serve).
  --all    --code --envs --sdk (default if no stage flag is given).

Weights are separate: scripts/download_weights.sh / make weights.
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
  edgejudge_require_cmd git

  echo "[bootstrap] Initializing git submodules"
  git -C "${REPO_ROOT}" submodule update --init --recursive

  local unidepth="${REPO_ROOT}/goal_stop_judge/depth_implementation/UniDepth"
  local grounded="${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2"

  edgejudge_clone_pinned "${UNIDEPTH_URL}" "${unidepth}" "${UNIDEPTH_SHA}" "UniDepth"
  edgejudge_clone_pinned "${GROUNDED_SAM_URL}" "${grounded}" "${GROUNDED_SAM_SHA}" "Grounded-SAM-2"
  edgejudge_ensure_omnivla_shim
}

bootstrap_envs() {
  local install_dir="${REPO_ROOT}/goal_stop_judge/envs"
  if [[ ! -f "${install_dir}/install_sim_env.sh" ]]; then
    echo "Missing ${install_dir}/install_sim_env.sh — run --code first." >&2
    exit 1
  fi
  edgejudge_init_conda

  echo "[bootstrap] Creating / updating conda env: sim"
  bash "${install_dir}/install_sim_env.sh"
  echo "[bootstrap] Creating / updating conda env: perception"
  bash "${install_dir}/install_perception_env.sh"
  if [[ "${DO_FULL}" -eq 1 ]]; then
    echo "[bootstrap] Creating / updating conda env: omnivla"
    bash "${install_dir}/install_omnivla_env.sh"
  else
    echo "[bootstrap] Skipping omnivla env (edge bring-up). Pass --full for local/remote full OmniVLA."
  fi
}

bootstrap_sdk() {
  local ws="${REPO_ROOT}/unofficial_sdk_unitree_go_2"
  if [[ ! -d "${ws}/src" ]]; then
    echo "Missing ${ws}/src — run --code first." >&2
    exit 1
  fi
  edgejudge_init_conda
  if ! edgejudge_conda_exists sim; then
    echo "conda env 'sim' not found. Run: ./scripts/bootstrap.sh --envs" >&2
    exit 1
  fi

  echo "[bootstrap] colcon build (go2_interfaces go2_robot_sdk)"
  (
    set +u
    conda activate sim
    set -u
    cd "${ws}"
    colcon build --packages-select go2_interfaces go2_robot_sdk
  )
}

echo "[bootstrap] repo: ${REPO_ROOT}"
[[ "${DO_CODE}" -eq 1 ]] && bootstrap_code
[[ "${DO_ENVS}" -eq 1 ]] && bootstrap_envs
[[ "${DO_SDK}" -eq 1 ]] && bootstrap_sdk
echo "[bootstrap] Done."
