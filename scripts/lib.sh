#!/usr/bin/env bash
# Shared helpers for EdgeJudge umbrella scripts. Source this file; do not run it.

_EDGEJUDGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_EDGEJUDGE_LIB_DIR}/.." && pwd)"

edgejudge_load_pins() {
  local pins="${_EDGEJUDGE_LIB_DIR}/pins.env"
  if [[ ! -f "${pins}" ]]; then
    echo "Missing pin file: ${pins}" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  set -a
  source "${pins}"
  set +a
}

edgejudge_load_dotenv() {
  local env_file="${REPO_ROOT}/.env"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

edgejudge_require_cmd() {
  local name="$1"
  if ! command -v "${name}" >/dev/null 2>&1; then
    echo "Missing command: ${name}" >&2
    return 1
  fi
}

# Populate GO2_CONDA_BASE and source conda.sh. Reuses the stack helper when the
# goal_stop_judge submodule is present; otherwise resolves conda the same way.
edgejudge_init_conda() {
  local conda_lib="${REPO_ROOT}/goal_stop_judge/envs/_conda_lib.sh"
  if [[ -f "${conda_lib}" ]]; then
    # shellcheck source=/dev/null
    source "${conda_lib}"
    _go2_clear_inherited_env
    _go2_init_conda
    return 0
  fi

  local base="${GO2_CONDA_BASE:-}"
  if [[ -z "${base}" ]] && command -v conda >/dev/null 2>&1; then
    base="$(conda info --base 2>/dev/null || true)"
  fi
  if [[ -z "${base}" || ! -f "${base}/etc/profile.d/conda.sh" ]]; then
    echo "Could not find conda. Install Miniforge and/or set GO2_CONDA_BASE." >&2
    echo "See SETUP.md." >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "${base}/etc/profile.d/conda.sh"
  export GO2_CONDA_BASE="${base}"
}

edgejudge_conda_exists() {
  local name="$1"
  conda env list 2>/dev/null | awk -v expected="${name}" '$1 == expected { found = 1 } END { exit !found }'
}

# Clone url into dest (if needed) and check out sha. Idempotent when already pinned.
edgejudge_clone_pinned() {
  local url="$1"
  local dest="$2"
  local sha="$3"
  local description="${4:-${dest}}"

  if [[ -d "${dest}/.git" ]]; then
    local current
    current="$(git -C "${dest}" rev-parse HEAD)"
    if [[ "${current}" == "${sha}"* || "${current}" == "${sha}" ]]; then
      echo "[pins] ${description} already at ${sha:0:12}"
      return 0
    fi
    echo "[pins] Updating ${description} -> ${sha:0:12}"
    git -C "${dest}" fetch --tags --recurse-submodules origin 2>/dev/null || git -C "${dest}" fetch origin
    if ! git -C "${dest}" checkout --detach "${sha}"; then
      git -C "${dest}" fetch origin "${sha}"
      git -C "${dest}" checkout --detach "${sha}"
    fi
    return 0
  fi

  if [[ -e "${dest}" && ! -d "${dest}/.git" ]]; then
    echo "Refusing to clone over non-git path: ${dest}" >&2
    return 1
  fi

  echo "[pins] Cloning ${description}"
  mkdir -p "$(dirname "${dest}")"
  git clone "${url}" "${dest}"
  git -C "${dest}" checkout --detach "${sha}"
}

# install_sim_env.sh / install_perception_env.sh look for omni-VLA/OmniVLA, but
# the Omni-VLA_Go2 submodule has inference/ at omni-VLA/. Point OmniVLA at `.`.
edgejudge_ensure_omnivla_shim() {
  local omnivla_root="${REPO_ROOT}/omni-VLA"
  local shim="${omnivla_root}/OmniVLA"
  if [[ ! -d "${omnivla_root}" ]]; then
    echo "Missing omni-VLA submodule at ${omnivla_root}. Run: git submodule update --init --recursive" >&2
    return 1
  fi
  if [[ -e "${shim}" && ! -L "${shim}" ]]; then
    echo "omni-VLA/OmniVLA exists and is not a symlink; leaving it alone." >&2
    return 0
  fi
  ln -sfn . "${shim}"
  echo "[shim] omni-VLA/OmniVLA -> ."
}

edgejudge_sam2_ckpt_path() {
  printf '%s\n' \
    "${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2/checkpoints/${SAM2_CKPT_NAME}"
}

edgejudge_require_file() {
  local path="$1"
  local hint="$2"
  if [[ ! -f "${path}" ]]; then
    echo "Missing ${path}" >&2
    echo "${hint}" >&2
    return 1
  fi
}
