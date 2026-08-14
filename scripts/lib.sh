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
    _go2_init_conda || return 1
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
  if declare -F _go2_env_exists >/dev/null 2>&1; then
    _go2_env_exists "${name}"
    return
  fi
  conda env list 2>/dev/null \
    | awk -v expected="${name}" '$1 == expected { found = 1 } END { exit !found }'
}

# Run a command inside a conda env. Requires edgejudge_init_conda first.
# nounset is off only while `conda activate` runs (its scripts leave unset vars).
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

edgejudge_sha_matches() {
  local current="$1"
  local sha="$2"
  [[ "${current}" == "${sha}" || "${current}" == "${sha}"* ]]
}

edgejudge_is_git_lfs_pointer() {
  local file="$1"
  [[ -f "${file}" ]] || return 1
  if head -n 1 "${file}" 2>/dev/null | grep -q '^version https://git-lfs.github.com/spec/v1'; then
    return 0
  fi
  return 1
}

edgejudge_checkout_sha() {
  local dest="$1"
  local sha="$2"
  if git -C "${dest}" cat-file -e "${sha}^{commit}" 2>/dev/null; then
    git -C "${dest}" checkout --detach "${sha}"
    return 0
  fi
  git -C "${dest}" fetch origin "${sha}"
  git -C "${dest}" checkout --detach "${sha}"
}

# Hugging Face repos store weights in Git LFS. Do not `git lfs pull` UniDepth /
# Grounded-SAM-2: those trees are source, and LFS (if present) can be huge.
edgejudge_maybe_lfs_pull() {
  local url="$1"
  local dest="$2"
  case "${url}" in
    *huggingface.co*) ;;
    *) return 0 ;;
  esac
  if ! command -v git-lfs >/dev/null 2>&1; then
    echo "[pins] git-lfs not found; ${dest} may still contain pointer files" >&2
    return 0
  fi
  git -C "${dest}" lfs install --local >/dev/null 2>&1 || true
  GIT_LFS_SKIP_SMUDGE=0 git -C "${dest}" lfs pull
}

# Clone url into dest (if needed) and check out sha. Idempotent when already pinned.
edgejudge_clone_pinned() {
  local url="$1"
  local dest="$2"
  local sha="$3"
  local description="${4:-${dest}}"
  local current

  if [[ -d "${dest}/.git" ]]; then
    current="$(git -C "${dest}" rev-parse HEAD)"
    if ! edgejudge_sha_matches "${current}" "${sha}"; then
      echo "[pins] Updating ${description} -> ${sha:0:12}"
      git -C "${dest}" fetch --tags --recurse-submodules origin 2>/dev/null \
        || git -C "${dest}" fetch origin
      edgejudge_checkout_sha "${dest}" "${sha}"
    else
      echo "[pins] ${description} already at ${sha:0:12}"
    fi
  else
    if [[ -e "${dest}" && ! -d "${dest}/.git" ]]; then
      if [[ -d "${dest}" && -z "$(ls -A "${dest}")" ]]; then
        rmdir "${dest}"
      else
        echo "Refusing to clone over non-git path: ${dest}" >&2
        echo "If this is a leftover from running make weights before make setup, remove it and re-run --code." >&2
        return 1
      fi
    fi

    echo "[pins] Cloning ${description}"
    mkdir -p "$(dirname "${dest}")"
    git clone "${url}" "${dest}"
    edgejudge_checkout_sha "${dest}" "${sha}"
  fi

  current="$(git -C "${dest}" rev-parse HEAD)"
  if ! edgejudge_sha_matches "${current}" "${sha}"; then
    echo "Failed to pin ${description} to ${sha} (HEAD=${current})" >&2
    return 1
  fi

  edgejudge_maybe_lfs_pull "${url}" "${dest}"
}

# Confirm a checkout's HEAD matches pins.env (full SHA or unique prefix).
edgejudge_require_git_head() {
  local path="$1"
  local sha="$2"
  local name="${3:-${path}}"
  if [[ ! -e "${path}/.git" ]]; then
    echo "Missing git checkout: ${path}" >&2
    return 1
  fi
  local current
  current="$(git -C "${path}" rev-parse HEAD)"
  if ! edgejudge_sha_matches "${current}" "${sha}"; then
    echo "${name} is at ${current}, expected ${sha}." >&2
    echo "Update the umbrella gitlink and scripts/pins.env together (see VERSIONS.md)." >&2
    return 1
  fi
  echo "[pins] ${name} ${current:0:12}"
}

# install_sim_env.sh / install_perception_env.sh look for omni-VLA/OmniVLA, but
# the Omni-VLA_Go2 submodule has inference/ at omni-VLA/. Point OmniVLA at `.`.
# Keep this as a self-symlink (not a nested directory): run_omnivla_edge.py loads
# ./omnivla-edge/omnivla-edge.pth from cwd, and install scripts cd to OmniVLA.
edgejudge_ensure_omnivla_shim() {
  local omnivla_root="${REPO_ROOT}/omni-VLA"
  local shim="${omnivla_root}/OmniVLA"
  if [[ ! -e "${omnivla_root}/.git" ]]; then
    echo "Missing omni-VLA submodule at ${omnivla_root}. Run: git submodule update --init --recursive" >&2
    return 1
  fi
  if [[ -e "${shim}" && ! -L "${shim}" ]]; then
    echo "omni-VLA/OmniVLA exists and is not a symlink; leaving it alone." >&2
    return 0
  fi
  ln -sfn . "${shim}"
  local probe="${shim}/inference/run_omnivla_edge.py"
  if [[ ! -f "${probe}" ]]; then
    echo "OmniVLA shim is broken: missing ${probe}" >&2
    return 1
  fi
  echo "[shim] omni-VLA/OmniVLA -> ."
}

edgejudge_download_file() {
  local url="$1"
  local dest="$2"
  local min_bytes="${3:-1000000}"
  local tmp="${dest}.tmp"
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
  local sz
  sz="$(wc -c < "${tmp}" | tr -d ' ')"
  if [[ "${sz}" -lt "${min_bytes}" ]]; then
    echo "Download too small (${sz} bytes, expected >= ${min_bytes}): ${url}" >&2
    rm -f "${tmp}"
    return 1
  fi
  mv "${tmp}" "${dest}"
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

# Real checkpoint: exists, is not a Git LFS pointer, and is at least min_bytes.
edgejudge_require_blob() {
  local path="$1"
  local hint="$2"
  local min_bytes="${3:-1000000}"
  local sz
  if [[ ! -f "${path}" ]]; then
    echo "Missing ${path}" >&2
    echo "${hint}" >&2
    return 1
  fi
  if edgejudge_is_git_lfs_pointer "${path}"; then
    echo "${path} is still a Git LFS pointer, not the real file." >&2
    echo "${hint}" >&2
    return 1
  fi
  sz="$(wc -c < "${path}" | tr -d ' ')"
  if [[ "${sz}" -lt "${min_bytes}" ]]; then
    echo "${path} is too small (${sz} bytes, expected >= ${min_bytes})." >&2
    echo "${hint}" >&2
    return 1
  fi
}

# Fail if any common weight file under dir is still an LFS pointer.
# Do not pass omni-VLA/ itself: the OmniVLA -> . shim would recurse.
edgejudge_fail_if_lfs_pointers() {
  local dir="$1"
  local hint="$2"
  local f
  if [[ ! -d "${dir}" ]]; then
    echo "Missing directory: ${dir}" >&2
    echo "${hint}" >&2
    return 1
  fi
  while IFS= read -r -d '' f; do
    if edgejudge_is_git_lfs_pointer "${f}"; then
      echo "Git LFS pointer still present: ${f}" >&2
      echo "${hint}" >&2
      return 1
    fi
  done < <(find -P "${dir}" -type f \( \
    -name '*.pth' -o -name '*.pt' -o -name '*.bin' -o \
    -name '*.safetensors' -o -name '*.ckpt' \) -print0 2>/dev/null)
}
