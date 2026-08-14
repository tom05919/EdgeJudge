#!/usr/bin/env bash
# Shared helpers for EdgeJudge umbrella scripts. Source this file; do not run it.

_EDGEJUDGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_EDGEJUDGE_LIB_DIR}/.." && pwd)"

edgejudge_load_pins() {
  set -a
  # shellcheck disable=SC1090
  source "${_EDGEJUDGE_LIB_DIR}/pins.env"
  set +a
}

edgejudge_load_dotenv() {
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${REPO_ROOT}/.env"
    set +a
  fi
}

# Requires goal_stop_judge (make setup / --code).
edgejudge_init_conda() {
  local conda_lib="${REPO_ROOT}/goal_stop_judge/envs/_conda_lib.sh"
  if [[ ! -f "${conda_lib}" ]]; then
    echo "Missing ${conda_lib}. Run: make setup" >&2
    return 1
  fi
  # shellcheck source=/dev/null
  source "${conda_lib}"
  _go2_clear_inherited_env
  _go2_init_conda
}

edgejudge_conda_exists() {
  _go2_env_exists "$1"
}

# nounset off only during `conda activate` (its scripts leave unset vars).
edgejudge_in_conda_env() {
  local env_name="$1"
  shift
  (
    set +u
    conda activate "${env_name}"
    set -u
    "$@"
  )
}

edgejudge_is_git_lfs_pointer() {
  [[ -f "$1" ]] && head -n 1 "$1" | grep -q '^version https://git-lfs.github.com/spec/v1'
}

# Clone url into dest and check out sha. Idempotent when already pinned.
# Hugging Face clones get `git lfs pull` when git-lfs is installed.
edgejudge_clone_pinned() {
  local url="$1" dest="$2" sha="$3" description="${4:-${2}}" current

  if [[ -d "${dest}/.git" ]]; then
    current="$(git -C "${dest}" rev-parse HEAD)"
    if [[ "${current}" == "${sha}"* ]]; then
      echo "[pins] ${description} already at ${sha:0:12}"
    else
      echo "[pins] Updating ${description} -> ${sha:0:12}"
      git -C "${dest}" fetch origin
      git -C "${dest}" checkout --detach "${sha}" \
        || { git -C "${dest}" fetch origin "${sha}"; git -C "${dest}" checkout --detach "${sha}"; }
    fi
  elif [[ -e "${dest}" ]]; then
    echo "Refusing to clone over non-git path: ${dest}" >&2
    echo "If this is leftover from make weights before make setup, remove it and re-run --code." >&2
    return 1
  else
    echo "[pins] Cloning ${description}"
    mkdir -p "$(dirname "${dest}")"
    git clone "${url}" "${dest}"
    git -C "${dest}" checkout --detach "${sha}"
  fi

  current="$(git -C "${dest}" rev-parse HEAD)"
  if [[ "${current}" != "${sha}"* ]]; then
    echo "Failed to pin ${description} to ${sha} (HEAD=${current})" >&2
    return 1
  fi

  if [[ "${url}" == *huggingface.co* ]] && command -v git-lfs >/dev/null 2>&1; then
    GIT_LFS_SKIP_SMUDGE=0 git -C "${dest}" lfs pull
  fi
}

# install_*_env.sh look for omni-VLA/OmniVLA; this submodule has inference/ at omni-VLA/.
# Self-symlink (not a nested dir): run_omnivla_edge.py loads ./omnivla-edge/*.pth from cwd.
edgejudge_ensure_omnivla_shim() {
  local root="${REPO_ROOT}/omni-VLA" shim="${REPO_ROOT}/omni-VLA/OmniVLA"
  if [[ ! -e "${root}/.git" ]]; then
    echo "Missing omni-VLA submodule. Run: git submodule update --init --recursive" >&2
    return 1
  fi
  if [[ -e "${shim}" && ! -L "${shim}" ]]; then
    echo "omni-VLA/OmniVLA exists and is not a symlink; leaving it alone." >&2
    return 0
  fi
  ln -sfn . "${shim}"
  echo "[shim] omni-VLA/OmniVLA -> ."
}

edgejudge_download_file() {
  local url="$1" dest="$2" tmp="${2}.tmp" sz
  mkdir -p "$(dirname "${dest}")"
  echo "[download] ${url}"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 -o "${tmp}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${tmp}" "${url}"
  else
    echo "Need curl or wget to download ${dest}" >&2
    return 1
  fi
  sz="$(wc -c < "${tmp}" | tr -d ' ')"
  if [[ "${sz}" -lt 1000000 ]]; then
    echo "Download too small (${sz} bytes): ${url}" >&2
    rm -f "${tmp}"
    return 1
  fi
  mv "${tmp}" "${dest}"
}

edgejudge_sam2_ckpt_path() {
  printf '%s\n' \
    "${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2/checkpoints/${SAM2_CKPT_NAME}"
}
