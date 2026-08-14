# Setup

This page explains what `make setup` / `make weights` / `make smoke` do, why
there are three conda environments, and how to override CUDA / conda paths.
For the live Go2 bring-up see [docs/real_robot.md](docs/real_robot.md).
Pins live in [VERSIONS.md](VERSIONS.md) and [`scripts/pins.env`](scripts/pins.env).

## Prerequisites

- Linux x86_64 with an NVIDIA GPU (edge + perception; full OmniVLA needs more VRAM)
- [Miniforge](https://github.com/conda-forge/miniforge) (conda + mamba)
- Git, [Git LFS](https://git-lfs.com) (Hugging Face checkpoints)
- `curl` or `wget` (SAM2 `.pt`)
- Optional: Docker Engine + Compose v2 for the driver image ([docker/README.md](docker/README.md))

Never `source /opt/ros` in these RoboStack environments. System ROS and conda
ROS will fight.

## One-command install

From the repository root:

```bash
git clone --recurse-submodules https://github.com/tom05919/EdgeJudge.git
cd EdgeJudge
cp .env.example .env
make setup      # ./scripts/bootstrap.sh --all
make weights    # OmniVLA-edge + SAM2 + Grounding DINO/UniDepth caches
make smoke
```

If you cloned without `--recurse-submodules`, `make setup` runs
`git submodule update --init --recursive` for you.

### Makefile targets

| Target | Script | What it does |
|--------|--------|----------------|
| `make setup` | `scripts/bootstrap.sh --all` | Submodules, UniDepth, Grounded-SAM-2, `omni-VLA/OmniVLA` shim, `sim` + `perception` envs, colcon SDK |
| `make setup-full` | `bootstrap.sh --all --full` | Also creates the `omnivla` env |
| `make weights` | `download_weights.sh --edge` | `omni-VLA/omnivla-edge`, SAM2 `.pt`, Grounding DINO + UniDepth snapshots |
| `make weights-full` | `download_weights.sh --full` | Also `omnivla-original` |
| `make smoke` | `smoke_test.sh` | Offline `stop_judge.py` on `examples/sample.png` |
| `make smoke-imports` | `smoke_test.sh --imports` | Env / `--help` only (no checkpoints) |
| `make driver` / `make nav` | | Track B — see [docs/real_robot.md](docs/real_robot.md) |

Equivalent without Make:

```bash
./scripts/bootstrap.sh --code
./scripts/bootstrap.sh --envs          # add --full for the omnivla env
./scripts/bootstrap.sh --sdk
./scripts/download_weights.sh --edge
./scripts/smoke_test.sh
```

`bootstrap.sh` with no flags is `--all` (code + envs + sdk, **not** `--full`).

## Why three conda environments

| Env | Used for | Default torch |
|-----|----------|----------------|
| `sim` | Go2 driver + OmniVLA-edge | 2.7 / cu126 |
| `perception` | Stop judge, 360° scan, remote ZMQ client | 2.6 / cu124, NumPy 2.2 |
| `omnivla` | Full OmniVLA local or `make serve` | 2.2 / cu121, NumPy 1.26 |

These are not optional style choices. RoboStack, UniDepth (NumPy 2), and
full OmniVLA (torch 2.2) do not coexist in one prefix. Do not mix packages
across envs. Recreate with
`bash goal_stop_judge/envs/install_<name>_env.sh --remove` then install again,
or `install_*_env.sh --update` to refresh an existing env.

`make setup` installs **sim + perception** only (enough for `--nav edge`).
Full / remote need `make setup-full` and `make weights-full`. Running
`make setup` again is a **no-op** if those conda envs already exist; refresh
with `./scripts/bootstrap.sh --envs --update` or
`bash goal_stop_judge/envs/install_<name>_env.sh --update`.

The install scripts live in `goal_stop_judge/envs/` and are called by
`scripts/bootstrap.sh`. Do not run them before `--code`: they require UniDepth,
Grounded-SAM-2, and the `omni-VLA/OmniVLA` shim.

## Layout shim (`omni-VLA/OmniVLA`)

`install_sim_env.sh` and `install_perception_env.sh` look for
`omni-VLA/OmniVLA`, but this submodule checks out Omni-VLA_Go2 **at**
`omni-VLA/` (`inference/` is at the root; `go2_nav.py` uses that path).
`bootstrap.sh --code` creates a symlink `omni-VLA/OmniVLA -> .` so both layouts
work. The symlink is gitignored. `.gitmodules` sets `ignore = untracked` on
`omni-VLA` and `goal_stop_judge` so UniDepth / weights / the shim do not show
up as dirty submodules.

## Environment variables

Copy [`.env.example`](.env.example) to `.env` (gitignored). `scripts/driver.sh`
and `scripts/nav.sh` source it.

| Variable | Purpose |
|----------|---------|
| `ROBOT_IP` | Go2 address (required for `make driver`) |
| `CONN_TYPE` | `webrtc` (default) or `cyclonedds` |
| `GO2_CONDA_BASE` | Miniforge root if `conda` is not on `PATH` |
| `GO2_TORCH_INDEX_URL` | Override PyTorch wheel index for `install_*_env.sh` |

## Hugging Face / Git LFS

`make weights` clones `https://huggingface.co/NHirose/omnivla-edge` and fails
if `omnivla-edge.pth` is missing or still a Git LFS pointer. If the directory
is only a few kilobytes:

```bash
git lfs install
./scripts/download_weights.sh --edge
```

It also `snapshot_download`s `IDEA-Research/grounding-dino-base` and
`lpiccinelli/unidepth-v2-vits14` into the Hugging Face cache. `stop_judge.py`
loads both with `local_files_only=True`, so `make smoke` cannot succeed until
those snapshots exist. Skip with `--no-hf-cache` only if you already have them.

A Hugging Face token is usually not required for these public repos.

## Smoke test

`make smoke` activates `perception`, checks imports, then runs:

```bash
python goal_stop_judge/stop_judge.py \
  --image examples/sample.png \
  --text-prompt "red cube." \
  --output-dir examples/smoke_output
```

If the SAM2 checkpoint is missing, is a Git LFS pointer, or the Grounding DINO
/ UniDepth caches are absent, it exits with `Run: make weights` rather than a
transformers stack trace. The synthetic sample is documented in
[examples/README.md](examples/README.md). Failures: [docs/troubleshooting.md](docs/troubleshooting.md).

## Docker

Docker does **not** replace `make setup`. The Compose file can run the Go2
driver or a CUDA + Miniforge shell; conda envs and weights still live on the
host (or in the mounted workspace). See [docker/README.md](docker/README.md).
Inside `stack-dev` you can run the same `make setup` / `make weights` commands.
