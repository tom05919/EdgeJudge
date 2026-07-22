# Go2 stop-judge + OmniVLA stack

Run the Unitree Go2 with a live stop judge and OmniVLA navigation via one CLI:

```bash
cd goal_stop_judge
python go2_nav.py
```

This README is the stack entry point (EdgeJudge umbrella or a local checkout of
the three project trees side by side).

## 1. Repo layout

| Path | Role |
|------|------|
| `goal_stop_judge/` | Orchestrator, stop judge, scan, ZMQ client, env manifests |
| `omni-VLA/` | OmniVLA-edge and full OmniVLA inference |
| `unofficial_sdk_unitree_go_2/` | Go2 ROS 2 driver (colcon root; packages under `src/`) |

Ignore `real_robot_SDKs/unitree_ros2/` and `Go2_Isaac_ros2/` unless you are
working on simulation. `goal_stop_judge/VLM_implementation/` is experimental and
is **not** used by `go2_nav.py`.

## 2. Getting started

Follow these steps in order on a machine that can reach the robot (and, for
**remote** nav, a GPU host for the full model).

### Step 1 — Clone the stack

Prefer the umbrella (pinned submodules):

```bash
git clone --recurse-submodules https://github.com/tom05919/EdgeJudge.git
cd EdgeJudge
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

Or clone the three trees by hand using the commands in
[VERSIONS.md](https://github.com/tom05919/VLM_goal_judge/blob/main/envs/VERSIONS.md).

### Step 2 — Clone perception deps and model weights

From the same directory that contains `goal_stop_judge/` and `omni-VLA/`:

```bash
# UniDepth + Grounded-SAM-2 (pinned SHAs — see VERSIONS.md)
git clone https://github.com/lpiccinelli-eth/UniDepth.git \
  goal_stop_judge/depth_implementation/UniDepth
git -C goal_stop_judge/depth_implementation/UniDepth \
  checkout 8d8cfe4c7ee15297099983607febf0d4f32eb3d6

git clone https://github.com/IDEA-Research/Grounded-SAM-2.git \
  goal_stop_judge/segmentation_implementation/Grounded-SAM-2
git -C goal_stop_judge/segmentation_implementation/Grounded-SAM-2 \
  checkout b7a9c29f196edff0eb54dbe14588d7ae5e3dde28

# OmniVLA weights (edge is enough for --nav edge; add original for full/remote)
git clone https://huggingface.co/NHirose/omnivla-edge omni-VLA/omnivla-edge
git -C omni-VLA/omnivla-edge checkout b1361b7e24f101edea795a98b00a826b61a97394

git clone https://huggingface.co/NHirose/omnivla-original omni-VLA/omnivla-original
git -C omni-VLA/omnivla-original checkout e36a84d4923c041149d441f93f3bdb7092bb5f07
```

Also place the SAM2 checkpoint `sam2.1_hiera_small.pt` under
`goal_stop_judge/segmentation_implementation/Grounded-SAM-2/checkpoints/`
(see [VERSIONS.md](https://github.com/tom05919/VLM_goal_judge/blob/main/envs/VERSIONS.md)).

### Step 3 — Create conda environments

Needs [Miniforge/Mambaforge](https://github.com/conda-forge/miniforge). Optional:
`export GO2_CONDA_BASE=/path/to/miniforge3`.

```bash
cd goal_stop_judge
bash envs/install_sim_env.sh
bash envs/install_perception_env.sh
bash envs/install_omnivla_env.sh   # needed for --nav full or GPU-host serve
```

| Env | Used for |
|-----|----------|
| `sim` | Go2 driver + OmniVLA-edge |
| `perception` | Stop judge, scan, remote ZMQ client |
| `omnivla` | Full OmniVLA local or `--mode serve` |

Do **not** mix packages across envs. Do **not** `source /opt/ros` with RoboStack.

### Step 4 — Build the Go2 ROS 2 SDK

```bash
conda activate sim
cd unofficial_sdk_unitree_go_2
rm -rf build install log
colcon build --packages-select go2_interfaces go2_robot_sdk
```

More detail: [RUNNING_GO2_SDK.md](unofficial_sdk_unitree_go_2/RUNNING_GO2_SDK.md).

### Step 5 — Every session: start the driver

**Terminal 1** (`sim`):

```bash
conda activate sim
cd unofficial_sdk_unitree_go_2
source install/setup.bash
export ROBOT_IP="192.168.x.x"   # your robot IP
export CONN_TYPE="webrtc"
ros2 launch go2_robot_sdk robot.launch.py nav2:=false slam:=false joystick:=false
```

Keep `teleop:=true` (default) so `twist_mux` forwards `/cmd_vel` → `/cmd_vel_out`.
Wait until the driver reports the robot ready (e.g. validated / standing).

### Step 6 — Run the stack wizard

**Terminal 2**:

```bash
cd goal_stop_judge
python go2_nav.py
```

Answer the prompts:

1. SAM2 detect string (e.g. `Human.`)
2. OmniVLA language goal (e.g. `go to the human with white shirt`)
3. Navigation mode — start with **edge** on first bring-up
4. Platform — **real** Go2 (or Isaac Sim)

What happens next: 360° scan + live stop judge → navigation → optional centering
after stop.

**Nav modes**

| Mode | Where the model runs |
|------|----------------------|
| `edge` | This PC (`sim`) — recommended first |
| `full` | This PC (`omnivla`) |
| `remote` | GPU host via ZeroMQ (see below) |

### Optional — remote full OmniVLA

On the **GPU host** first (`omnivla` env; no `go2_nav` required):

```bash
cd omni-VLA
python inference/run_omnivla.py --mode serve --bind tcp://*:5555
```

On the robot PC, choose **remote** in the wizard and set
`tcp://<gpu-host-ip>:5555` (not `localhost` unless the server is local).

## 3. Advanced / non-interactive

```bash
cd goal_stop_judge

python go2_nav.py run --sam "fire extinguisher." --vla "go to fire extinguisher" --nav edge
python go2_nav.py run --sam "..." --vla "..." --nav full
python go2_nav.py run --sam "..." --vla "..." --nav remote \
  --endpoint tcp://195.251.89.102:5555

python go2_nav.py run --nav edge --sim   # Isaac Sim topic names

# Same stack; --text-prompt is the SAM alias for --sam
python run_robot_stack.py --navigation remote \
  --server-endpoint tcp://195.251.89.102:5555 --text-prompt "Human."
```

## 4. Config knobs

| Knob | Where | Notes |
|------|--------|------|
| SAM2 detect prompt | wizard / `--sam` | Also `--text-prompt` on `run_robot_stack.py` |
| OmniVLA language | wizard / `--vla` | Passed to edge / full / remote as `--text-prompt` |
| `--stop-distance` | `go2_nav run` | Default 1.0 m |
| `--min-interval` | `go2_nav run` | Min seconds between stop evaluations |
| Velocity clamps | `server_client.py` | `MAX_LINEAR=0.3`, `MAX_ANGULAR=0.4` (remote) |
| Checkpoint / resume | `InferenceConfig` in `run_omnivla.py` | Default original/`120000` |
| Conda root | `GO2_CONDA_BASE` | Portable; no hardcoded miniforge path |

Hard stop: `Ctrl+C` on the driver and stack terminals.

## 5. Troubleshooting

| Symptom | What to try |
|---------|-------------|
| `go2_nav.py --help` needs ROS | Update stack; `center_target` must be lazy-imported |
| Nav never starts | Wait for **`SCAN_DONE`**; check stop_judge logs for crashes |
| No camera / no motion | Driver up? `ros2 topic hz /camera/image_raw`; `teleop:=true` |
| Remote timeouts | Serve on GPU host; open port 5555; use real host IP in `--endpoint` |
| NumPy / ROS fights | Re-run that env’s `install_*_env.sh --update` |
| VRAM OOM on full local | Use `--nav edge`, or `--nav remote` on a larger GPU |
| Env recreate | `bash envs/install_<name>_env.sh --remove` then install again |

## 6. Further docs

Links below point at the GitHub files (submodule paths do not resolve as relative
links on the EdgeJudge repo page).

| Doc | Use |
|-----|-----|
| [VERSIONS.md](https://github.com/tom05919/VLM_goal_judge/blob/main/envs/VERSIONS.md) | SHAs, weights, clone pins |
| [goal_stop_judge/envs/](https://github.com/tom05919/VLM_goal_judge/tree/main/envs) | `environment-*.yml`, install scripts |
| [RUNNING_GO2_SDK.md](unofficial_sdk_unitree_go_2/RUNNING_GO2_SDK.md) | Colcon build / RoboStack SDK (tracked in this repo) |
| [REAL_ROBOT_GO2.md](https://github.com/tom05919/Omni-VLA_Go2/blob/main/REAL_ROBOT_GO2.md) | Driver topics, launch flags, hardware traps |
| [SETUP.md](https://github.com/tom05919/Omni-VLA_Go2/blob/main/SETUP.md) | Upstream OmniVLA setup notes |
| [VLM_implementation/](https://github.com/tom05919/VLM_goal_judge/tree/main/VLM_implementation) | Experimental; out of scope for this stack |
