# EdgeJudge pins

This file is the **umbrella contract** for a reproducible checkout. Scripts read
the same values from [`scripts/pins.env`](scripts/pins.env). Do not copy-paste
SHAs from a submodule README; change `scripts/pins.env` and this file together.

## Expected layout

After `make setup` (and `make weights` for checkpoints):

```
EdgeJudge/
├── goal_stop_judge/                          # submodule: VLM_goal_judge
│   ├── depth_implementation/UniDepth/        # cloned by bootstrap --code
│   └── segmentation_implementation/
│       └── Grounded-SAM-2/                   # cloned by bootstrap --code
│           └── checkpoints/sam2.1_hiera_small.pt
├── omni-VLA/                                 # submodule: Omni-VLA_Go2
│   ├── OmniVLA -> .                          # shim for install_*_env.sh
│   ├── inference/
│   └── omnivla-edge/                         # Hugging Face (make weights)
├── unofficial_sdk_unitree_go_2/              # colcon workspace
│   └── src/                                  # submodule: go2_ros2_sdk
├── examples/sample.png
├── scripts/
└── docker/
```

`git clone --recurse-submodules` only fetches the three submodules. UniDepth,
Grounded-SAM-2, and weights are **not** git submodules; `scripts/bootstrap.sh`
and `scripts/download_weights.sh` clone them to the paths above.

## Git submodules

| Path | URL | SHA |
|------|-----|-----|
| `goal_stop_judge` | https://github.com/tom05919/VLM_goal_judge.git | `7d37d008ae1c01db42c6f4e5bf792e9e4585af2f` |
| `omni-VLA` | https://github.com/tom05919/Omni-VLA_Go2.git | `80c1833c0616cbe2ff1f21f3065c573950daf1de` |
| `unofficial_sdk_unitree_go_2/src` | https://github.com/abizovnuralem/go2_ros2_sdk.git | `4e186b5f89bfec1f32c85676cbe22d4958e4f0fa` |

These SHAs must match `.gitmodules` / `git submodule status`.

## Perception sources

| Tree | URL | SHA |
|------|-----|-----|
| `goal_stop_judge/depth_implementation/UniDepth` | https://github.com/lpiccinelli-eth/UniDepth.git | `8d8cfe4c7ee15297099983607febf0d4f32eb3d6` |
| `goal_stop_judge/segmentation_implementation/Grounded-SAM-2` | https://github.com/IDEA-Research/Grounded-SAM-2.git | `b7a9c29f196edff0eb54dbe14588d7ae5e3dde28` |

## Model weights

| Artifact | Source | Pin |
|----------|--------|-----|
| OmniVLA-edge | https://huggingface.co/NHirose/omnivla-edge | `b1361b7e24f101edea795a98b00a826b61a97394` |
| OmniVLA original (full / remote) | https://huggingface.co/NHirose/omnivla-original | `e36a84d4923c041149d441f93f3bdb7092bb5f07` |
| OmniVLA CAST finetune (optional) | https://huggingface.co/NHirose/omnivla-finetuned-cast | `7d3744a72cd89218be4d223783f0742819b6c6db` |
| SAM2 `sam2.1_hiera_small.pt` | [Meta checkpoint](https://dl.fbaipublicfiles.com/segment_anything_2/092824/sam2.1_hiera_small.pt) | filename pin |

HF clones land under `omni-VLA/omnivla-{edge,original,finetuned-cast}/`.
The SAM2 file lands in `Grounded-SAM-2/checkpoints/`.

Caches pulled on first run (not pinned as git SHAs):

- Grounding DINO: `IDEA-Research/grounding-dino-base`
- UniDepth: `lpiccinelli/unidepth-v2-vits14`

Full OmniVLA `InferenceConfig`: original `vla_path=./omnivla-original`, `resume_step=120000`; CAST `vla_path=./omnivla-finetuned-cast`, `resume_step=210000`.

## Conda environments

Do **not** mix packages across envs. Do **not** `source /opt/ros` with RoboStack.

| Env | Python | Role | Torch (default index) |
|-----|--------|------|------------------------|
| `sim` | 3.11 | Go2 driver + OmniVLA-edge | 2.7 / cu126 |
| `perception` | 3.11 | Stop judge, scan, ZMQ client | 2.6 / cu124, NumPy 2.2 |
| `omnivla` | 3.11 | Full OmniVLA local or serve | 2.2 / cu121, NumPy 1.26 |

`make setup` creates `sim` and `perception` only. Pass `make setup-full` (or
`./scripts/bootstrap.sh --all --full`) for the `omnivla` env.

Override the CUDA wheel index with `GO2_TORCH_INDEX_URL`. Override the conda
root with `GO2_CONDA_BASE`.
