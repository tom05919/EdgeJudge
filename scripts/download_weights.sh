#!/usr/bin/env bash
# Download pinned OmniVLA checkpoints, the SAM2 weight file, and the Hugging
# Face caches that stop_judge.py needs (Grounding DINO + UniDepth).
#
#   ./scripts/download_weights.sh           # omnivla-edge + SAM2 + HF caches
#   ./scripts/download_weights.sh --full    # also omnivla-original
#   ./scripts/download_weights.sh --all     # edge + original + CAST + SAM2
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv
edgejudge_load_pins

DO_EDGE=1
DO_ORIGINAL=0
DO_CAST=0
DO_SAM2=1
DO_HF_CACHE=1

LFS_HINT="Install git-lfs (https://git-lfs.com) and re-run make weights."

usage() {
  cat <<'EOF'
Usage: scripts/download_weights.sh [--edge] [--full] [--cast] [--all] [--no-sam2] [--no-hf-cache]

  --edge        OmniVLA-edge into omni-VLA/omnivla-edge (default; enough for --nav edge)
  --full        Also clone omnivla-original (local full / remote serve)
  --cast        Also clone omnivla-finetuned-cast
  --all         --edge --full --cast
  --no-sam2     Skip sam2.1_hiera_small.pt
  --no-hf-cache Skip Grounding DINO / UniDepth snapshot_download (needed for make smoke)

Requires git. Hugging Face repos use Git LFS; install git-lfs if clone is a stub.
Grounded-SAM-2 + the perception env must already exist (make setup).
EOF
}

if [[ $# -gt 0 ]]; then
  DO_EDGE=0
  DO_ORIGINAL=0
  DO_CAST=0
  HAVE_WEIGHT=0
  for arg in "$@"; do
    case "${arg}" in
      --edge) DO_EDGE=1; HAVE_WEIGHT=1 ;;
      --full) DO_EDGE=1; DO_ORIGINAL=1; HAVE_WEIGHT=1 ;;
      --cast) DO_CAST=1; HAVE_WEIGHT=1 ;;
      --all) DO_EDGE=1; DO_ORIGINAL=1; DO_CAST=1; HAVE_WEIGHT=1 ;;
      --no-sam2) DO_SAM2=0 ;;
      --no-hf-cache) DO_HF_CACHE=0 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: ${arg}" >&2; usage >&2; exit 2 ;;
    esac
  done
  if [[ "${HAVE_WEIGHT}" -eq 0 ]]; then
    DO_EDGE=1
  fi
fi

edgejudge_require_cmd git

if [[ ! -e "${REPO_ROOT}/omni-VLA/.git" ]]; then
  echo "Missing omni-VLA submodule. Run: make setup   (or ./scripts/bootstrap.sh --code)" >&2
  exit 1
fi

if [[ "${DO_EDGE}" -eq 1 || "${DO_ORIGINAL}" -eq 1 || "${DO_CAST}" -eq 1 ]]; then
  if ! command -v git-lfs >/dev/null 2>&1; then
    echo "[weights] Warning: git-lfs not found. Hugging Face checkpoints may be pointer files." >&2
    echo "[weights] Install git-lfs (https://git-lfs.com) and re-run if omnivla-edge is tiny." >&2
  fi
fi

if [[ "${DO_EDGE}" -eq 1 ]]; then
  edgejudge_clone_pinned \
    "${OMNIVLA_EDGE_URL}" \
    "${REPO_ROOT}/omni-VLA/omnivla-edge" \
    "${OMNIVLA_EDGE_SHA}" \
    "omnivla-edge"
  edgejudge_require_blob \
    "${REPO_ROOT}/omni-VLA/omnivla-edge/omnivla-edge.pth" \
    "${LFS_HINT} (run_omnivla_edge.py loads this file from cwd omni-VLA/)."
fi

if [[ "${DO_ORIGINAL}" -eq 1 ]]; then
  edgejudge_clone_pinned \
    "${OMNIVLA_ORIGINAL_URL}" \
    "${REPO_ROOT}/omni-VLA/omnivla-original" \
    "${OMNIVLA_ORIGINAL_SHA}" \
    "omnivla-original"
  edgejudge_fail_if_lfs_pointers \
    "${REPO_ROOT}/omni-VLA/omnivla-original" \
    "${LFS_HINT}"
fi

if [[ "${DO_CAST}" -eq 1 ]]; then
  edgejudge_clone_pinned \
    "${OMNIVLA_CAST_URL}" \
    "${REPO_ROOT}/omni-VLA/omnivla-finetuned-cast" \
    "${OMNIVLA_CAST_SHA}" \
    "omnivla-finetuned-cast"
  edgejudge_fail_if_lfs_pointers \
    "${REPO_ROOT}/omni-VLA/omnivla-finetuned-cast" \
    "${LFS_HINT}"
fi

if [[ "${DO_SAM2}" -eq 1 ]]; then
  gsam_root="${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2"
  if [[ ! -d "${gsam_root}/.git" ]]; then
    echo "Grounded-SAM-2 is not cloned at ${gsam_root}" >&2
    echo "Run: make setup   (or ./scripts/bootstrap.sh --code) before make weights." >&2
    echo "Do not mkdir that path by hand — it blocks the pinned git clone." >&2
    exit 1
  fi
  local_ckpt="$(edgejudge_sam2_ckpt_path)"
  if [[ -f "${local_ckpt}" ]] && ! edgejudge_is_git_lfs_pointer "${local_ckpt}"; then
    sz="$(wc -c < "${local_ckpt}" | tr -d ' ')"
    if [[ "${sz}" -ge 1000000 ]]; then
      echo "[weights] SAM2 checkpoint already present: ${local_ckpt}"
    else
      echo "[weights] Existing ${SAM2_CKPT_NAME} is too small (${sz} bytes); re-downloading"
      rm -f "${local_ckpt}"
      edgejudge_download_file "${SAM2_CKPT_URL}" "${local_ckpt}"
    fi
  else
    rm -f "${local_ckpt}"
    edgejudge_download_file "${SAM2_CKPT_URL}" "${local_ckpt}"
  fi
  edgejudge_require_blob "${local_ckpt}" "Re-run make weights (SAM2 download failed)."
fi

if [[ "${DO_HF_CACHE}" -eq 1 ]]; then
  edgejudge_init_conda
  if ! edgejudge_conda_exists perception; then
    echo "[weights] Skipping Hugging Face cache prefetch (conda env 'perception' not found)." >&2
    echo "[weights] make smoke needs local copies of ${GROUNDING_DINO_MODEL} and ${UNIDEPTH_HF_MODEL}" >&2
    echo "[weights] (stop_judge loads them with local_files_only=True). Run make setup first." >&2
  else
    echo "[weights] Prefetching Hugging Face snapshots for stop_judge (local_files_only)"
    edgejudge_in_conda_env perception python -c "
from huggingface_hub import snapshot_download
for repo in ('${GROUNDING_DINO_MODEL}', '${UNIDEPTH_HF_MODEL}'):
    print('[weights] snapshot_download', repo, flush=True)
    snapshot_download(repo)
print('[weights] HF cache ready', flush=True)
"
  fi
fi

echo "[weights] Done."
