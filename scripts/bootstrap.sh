#!/usr/bin/env bash
# Bootstrap EdgeJudge code deps, conda envs, and the Go2 SDK.
#
#   ./scripts/bootstrap.sh           # --all (code + sim/perception envs + sdk)
#   ./scripts/bootstrap.sh --code    # submodules, UniDepth, Grounded-SAM-2, shim
#   ./scripts/bootstrap.sh --envs    # sim + perception (add --full for omnivla)
#   ./scripts/bootstrap.sh --sdk     # colcon build go2_interfaces + go2_robot_sdk
#   ./scripts/bootstrap.sh --all --full
#   ./scripts/bootstrap.sh --envs --update   # refresh existing conda envs
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
DO_UPDATE=0
HAVE_STAGE=0

usage() {
  cat <<'EOF'
Usage: scripts/bootstrap.sh [--code] [--envs] [--sdk] [--full] [--all] [--update]

  --code    Init git submodules; clone UniDepth + Grounded-SAM-2 at pinned SHAs;
            create omni-VLA/OmniVLA -> . so install_*_env.sh can find the tree.
  --envs    Create conda envs sim and perception (requires --code first).
            If an env already exists, the install script exits 0 without
            changing it unless you also pass --update.
  --sdk     colcon build go2_interfaces + go2_robot_sdk inside unofficial_sdk_unitree_go_2
            (requires sim env).
  --full    With --envs, also create the omnivla env (full / remote serve).
  --all     --code --envs --sdk (default if no stage flag is given).
  --update  Forward --update to install_*_env.sh (refresh existing envs).

Weights are separate: scripts/download_weights.sh / make weights.
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --code) DO_CODE=1; HAVE_STAGE=1 ;;
    --envs) DO_ENVS=1; HAVE_STAGE=1 ;;
    --sdk) DO_SDK=1; HAVE_STAGE=1 ;;
    --full) DO_FULL=1 ;;
    --update) DO_UPDATE=1 ;;
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

  edgejudge_require_git_head \
    "${REPO_ROOT}/goal_stop_judge" "${GOAL_STOP_JUDGE_SHA}" "goal_stop_judge"
  edgejudge_require_git_head \
    "${REPO_ROOT}/omni-VLA" "${OMNIVLA_SHA}" "omni-VLA"
  edgejudge_require_git_head \
    "${REPO_ROOT}/unofficial_sdk_unitree_go_2/src" "${GO2_SDK_SHA}" "go2_ros2_sdk"

  if [[ ! -f "${REPO_ROOT}/goal_stop_judge/go2_nav.py" || \
        ! -f "${REPO_ROOT}/goal_stop_judge/envs/install_sim_env.sh" ]]; then
    echo "goal_stop_judge checkout is missing go2_nav.py / envs/install_sim_env.sh." >&2
    echo "Expected pin ${GOAL_STOP_JUDGE_SHA} (see VERSIONS.md)." >&2
    exit 1
  fi

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
  # install_*_env.sh cd to omni-VLA/OmniVLA and require UniDepth + Grounded-SAM-2.
  edgejudge_ensure_omnivla_shim
  if [[ ! -d "${REPO_ROOT}/goal_stop_judge/depth_implementation/UniDepth/.git" || \
        ! -d "${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2/.git" ]]; then
    echo "UniDepth / Grounded-SAM-2 are not cloned. Run: ./scripts/bootstrap.sh --code" >&2
    exit 1
  fi
  edgejudge_init_conda

  echo "[bootstrap] conda env sim (no-op if it exists, unless --update)"
  bash "${install_dir}/install_sim_env.sh" ${DO_UPDATE:+--update}
  echo "[bootstrap] conda env perception (no-op if it exists, unless --update)"
  bash "${install_dir}/install_perception_env.sh" ${DO_UPDATE:+--update}
  if [[ "${DO_FULL}" -eq 1 ]]; then
    echo "[bootstrap] conda env omnivla (no-op if it exists, unless --update)"
    bash "${install_dir}/install_omnivla_env.sh" ${DO_UPDATE:+--update}
  else
    echo "[bootstrap] Skipping omnivla env (edge bring-up). Pass --full for local/remote full OmniVLA."
  fi
}

bootstrap_sdk() {
  local ws="${REPO_ROOT}/unofficial_sdk_unitree_go_2"
  if [[ ! -d "${ws}/src/go2_robot_sdk" || ! -d "${ws}/src/go2_interfaces" ]]; then
    echo "Missing go2_robot_sdk / go2_interfaces under ${ws}/src — run --code first." >&2
    exit 1
  fi
  if [[ ! -e "${ws}/src/go2_robot_sdk/external_lib/aioice/.git" ]]; then
    echo "[bootstrap] Initializing nested aioice submodule"
    git -C "${ws}/src" submodule update --init --recursive
  fi
  edgejudge_init_conda
  if ! edgejudge_conda_exists sim; then
    echo "conda env 'sim' not found. Run: ./scripts/bootstrap.sh --envs" >&2
    exit 1
  fi

  echo "[bootstrap] colcon build (go2_interfaces go2_robot_sdk)"
  edgejudge_in_conda_env sim bash -c '
    set -euo pipefail
    if ! command -v colcon >/dev/null 2>&1; then
      echo "colcon not found in the sim env. Re-run: bash goal_stop_judge/envs/install_sim_env.sh --update" >&2
      exit 1
    fi
    cd "$1"
    colcon build --packages-select go2_interfaces go2_robot_sdk
  ' bash "${ws}"
}

echo "[bootstrap] repo: ${REPO_ROOT}"
[[ "${DO_CODE}" -eq 1 ]] && bootstrap_code
[[ "${DO_ENVS}" -eq 1 ]] && bootstrap_envs
[[ "${DO_SDK}" -eq 1 ]] && bootstrap_sdk
echo "[bootstrap] Done."
