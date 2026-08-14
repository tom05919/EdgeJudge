# Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `make setup` cannot find conda | Install Miniforge; `export GO2_CONDA_BASE=/path/to/miniforge3` or set it in `.env` |
| `install_sim_env.sh` missing `omni-VLA/OmniVLA` | Run `make setup` / `./scripts/bootstrap.sh --code` (creates the shim symlink) |
| `install_perception_env.sh` missing UniDepth / Grounded-SAM-2 | Same: `--code` clones those trees to the paths the install scripts expect |
| `make weights` before `make setup` | `--code` first. Weights will refuse to mkdir `Grounded-SAM-2/` (that would block the git clone) |
| `make smoke` asks for weights | `make weights` (Git LFS + SAM2 `.pt` + Grounding DINO/UniDepth snapshots) |
| `FileNotFoundError` Grounding DINO / `local_files_only` | `make weights` prefetches `IDEA-Research/grounding-dino-base` and `lpiccinelli/unidepth-v2-vits14`. If you passed `--no-hf-cache`, run `huggingface-cli download` for those repos in the `perception` env |
| Docker build hangs / huge context | Ensure `.dockerignore` lists `omni-VLA/OmniVLA` (the layout shim is a self-symlink) |
| Hugging Face clone is a few KB | `git lfs install` and re-run `make weights` |
| `go2_nav.py --help` needs ROS | Update the `goal_stop_judge` submodule; `center_target` must be lazy-imported |
| Nav never starts | Wait for **`SCAN_DONE`**; check stop_judge logs for crashes |
| No camera / no motion | Driver up? `ros2 topic hz /camera/image_raw`; keep `teleop:=true` |
| Remote timeouts | Serve on the GPU host; open port 5555; use the host IP in `--endpoint` ([remote.md](remote.md)) |
| NumPy / ROS fights | Re-run that env’s `install_*_env.sh --update`; do not `source /opt/ros` |
| VRAM OOM on full local | `--nav edge`, or `--nav remote` on a larger GPU |
| Env recreate | `bash goal_stop_judge/envs/install_<name>_env.sh --remove` then install again |
| `colcon` `--editable not recognized` | `pip install "setuptools<80" "packaging<25"` in `sim`; see [RUNNING_GO2_SDK.md](../unofficial_sdk_unitree_go_2/RUNNING_GO2_SDK.md) |

SDK-specific gotchas (wrong `source` path, stale `install/` shebangs, Foxglove
package missing) are documented in
[RUNNING_GO2_SDK.md](../unofficial_sdk_unitree_go_2/RUNNING_GO2_SDK.md).
