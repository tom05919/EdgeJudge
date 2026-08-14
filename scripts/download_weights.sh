#!/usr/bin/env bash
# Download pinned OmniVLA checkpoints and the SAM2 weight file.
#
#   ./scripts/download_weights.sh           # omnivla-edge + SAM2 (default)
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

usage() {
  cat <<'EOF'
Usage: scripts/download_weights.sh [--edge] [--full] [--cast] [--all] [--no-sam2]

  --edge     OmniVLA-edge into omni-VLA/omnivla-edge (default; enough for --nav edge)
  --full     Also clone omnivla-original (local full / remote serve)
  --cast     Also clone omnivla-finetuned-cast
  --all      --edge --full --cast
  --no-sam2  Skip sam2.1_hiera_small.pt

Requires git. Hugging Face repos use Git LFS; install git-lfs if clone is a stub.
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
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown arg: ${arg}" >&2; usage >&2; exit 2 ;;
    esac
  done
  if [[ "${HAVE_WEIGHT}" -eq 0 ]]; then
    DO_EDGE=1
  fi
fi

edgejudge_require_cmd git

if [[ ! -d "${REPO_ROOT}/omni-VLA" ]]; then
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

if [[ "${DO_SAM2}" -eq 1 ]]; then
  local_ckpt="$(edgejudge_sam2_ckpt_path)"
  mkdir -p "$(dirname "${local_ckpt}")"
  if [[ -f "${local_ckpt}" && -s "${local_ckpt}" ]]; then
    echo "[weights] SAM2 checkpoint already present: ${local_ckpt}"
  else
    echo "[weights] Downloading ${SAM2_CKPT_NAME}"
    if command -v curl >/dev/null 2>&1; then
      curl -fL --retry 3 -o "${local_ckpt}" "${SAM2_CKPT_URL}"
    elif command -v wget >/dev/null 2>&1; then
      wget -O "${local_ckpt}" "${SAM2_CKPT_URL}"
    else
      echo "Need curl or wget to download ${SAM2_CKPT_NAME}" >&2
      exit 1
    fi
  fi
fi

echo "[weights] Done."
