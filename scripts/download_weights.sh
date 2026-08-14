#!/usr/bin/env bash
# Download OmniVLA-edge, SAM2, and the HF caches stop_judge needs.
#
#   ./scripts/download_weights.sh         # edge + SAM2 + Grounding DINO/UniDepth
#   ./scripts/download_weights.sh --full  # also omnivla-original
#   ./scripts/download_weights.sh --all   # also CAST
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv
edgejudge_load_pins

DO_ORIGINAL=0
DO_CAST=0

usage() {
  cat <<'EOF'
Usage: scripts/download_weights.sh [--full] [--all]

  (default)  omnivla-edge + sam2.1_hiera_small.pt + HF perception caches
  --full     also omnivla-original
  --all      also omnivla-original and omnivla-finetuned-cast

Needs git, git-lfs, and make setup (omni-VLA, Grounded-SAM-2, perception env).
EOF
}

for arg in "$@"; do
  case "${arg}" in
    --edge) ;;
    --full) DO_ORIGINAL=1 ;;
    --all) DO_ORIGINAL=1; DO_CAST=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: ${arg}" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ ! -e "${REPO_ROOT}/omni-VLA/.git" ]]; then
  echo "Missing omni-VLA submodule. Run: make setup" >&2
  exit 1
fi

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "[weights] git-lfs not found; Hugging Face clones may be pointer files." >&2
fi

edgejudge_clone_pinned \
  "${OMNIVLA_EDGE_URL}" \
  "${REPO_ROOT}/omni-VLA/omnivla-edge" \
  "${OMNIVLA_EDGE_SHA}" \
  "omnivla-edge"
edge_pth="${REPO_ROOT}/omni-VLA/omnivla-edge/omnivla-edge.pth"
if [[ ! -s "${edge_pth}" ]] || edgejudge_is_git_lfs_pointer "${edge_pth}"; then
  echo "omnivla-edge.pth is missing or still a Git LFS pointer." >&2
  echo "Install git-lfs (https://git-lfs.com) and re-run make weights." >&2
  exit 1
fi

if [[ "${DO_ORIGINAL}" -eq 1 ]]; then
  edgejudge_clone_pinned \
    "${OMNIVLA_ORIGINAL_URL}" \
    "${REPO_ROOT}/omni-VLA/omnivla-original" \
    "${OMNIVLA_ORIGINAL_SHA}" \
    "omnivla-original"
fi

if [[ "${DO_CAST}" -eq 1 ]]; then
  edgejudge_clone_pinned \
    "${OMNIVLA_CAST_URL}" \
    "${REPO_ROOT}/omni-VLA/omnivla-finetuned-cast" \
    "${OMNIVLA_CAST_SHA}" \
    "omnivla-finetuned-cast"
fi

gsam="${REPO_ROOT}/goal_stop_judge/segmentation_implementation/Grounded-SAM-2"
if [[ ! -d "${gsam}/.git" ]]; then
  echo "Grounded-SAM-2 is not cloned. Run make setup before make weights." >&2
  echo "Do not mkdir that path by hand — it blocks the pinned git clone." >&2
  exit 1
fi
ckpt="$(edgejudge_sam2_ckpt_path)"
if [[ -s "${ckpt}" ]] && ! edgejudge_is_git_lfs_pointer "${ckpt}"; then
  echo "[weights] SAM2 checkpoint already present: ${ckpt}"
else
  rm -f "${ckpt}"
  edgejudge_download_file "${SAM2_CKPT_URL}" "${ckpt}"
fi

if edgejudge_init_conda && edgejudge_conda_exists perception; then
  echo "[weights] Prefetching Grounding DINO + UniDepth (stop_judge uses local_files_only)"
  edgejudge_in_conda_env perception python -c "
from huggingface_hub import snapshot_download
for repo in ('${GROUNDING_DINO_MODEL}', '${UNIDEPTH_HF_MODEL}'):
    print('[weights]', repo, flush=True)
    snapshot_download(repo)
"
else
  echo "[weights] Skip HF cache prefetch (need make setup / perception env)." >&2
fi

echo "[weights] Done."
