# Track B — Real Unitree Go2

Finish [Track A](../README.md) (`make setup`, `make weights`, `make smoke`)
before this page. Set `ROBOT_IP` in `.env` (see [`.env.example`](../.env.example)).

## Every session: start the driver

**Terminal 1** — native (`sim` env):

```bash
make driver
```

Equivalent:

```bash
conda activate sim
cd unofficial_sdk_unitree_go_2
source install/setup.bash
export ROBOT_IP="192.168.x.x"   # or source ../../.env
export CONN_TYPE="${CONN_TYPE:-webrtc}"
ros2 launch go2_robot_sdk robot.launch.py nav2:=false slam:=false joystick:=false
```

Keep `teleop:=true` (launch default) so `twist_mux` forwards `/cmd_vel` →
`/cmd_vel_out`. Wait until the driver reports the robot ready (validated /
standing).

**Docker alternative** (builds `edgejudge-go2` from `docker/Dockerfile.go2`):

```bash
export ROBOT_IP="192.168.x.x"
docker compose -f docker/docker-compose.yml up --build go2_driver
```

More driver detail: [RUNNING_GO2_SDK.md](../unofficial_sdk_unitree_go_2/RUNNING_GO2_SDK.md),
[REAL_ROBOT_GO2.md](https://github.com/tom05919/Omni-VLA_Go2/blob/main/REAL_ROBOT_GO2.md).

## Run the stack

**Terminal 2:**

```bash
make nav
```

This is `python goal_stop_judge/go2_nav.py`. Answer the prompts:

1. SAM2 detect string (e.g. `Human.`)
2. OmniVLA language goal (e.g. `go to the human with white shirt`)
3. Navigation mode — start with **edge**
4. Platform — **real** Go2 (or Isaac Sim)

What happens next: 360° scan + live stop judge → navigation → optional
centering after stop.

### Non-interactive

```bash
./scripts/nav.sh run --sam "fire extinguisher." --vla "go to fire extinguisher" --nav edge
./scripts/nav.sh run --sam "Human." --vla "go to the human with white shirt" --nav full
./scripts/nav.sh run --nav edge --sim
```

Same stack without Make:

```bash
cd goal_stop_judge
python go2_nav.py run --sam "Human." --vla "go to the human with white shirt" --nav edge
python run_robot_stack.py --navigation remote \
  --server-endpoint tcp://HOST:5555 --text-prompt "Human."
```

Remote full OmniVLA: [remote.md](remote.md).

## Config knobs

| Knob | Where | Notes |
|------|--------|------|
| SAM2 detect prompt | wizard / `--sam` | Also `--text-prompt` on `run_robot_stack.py` |
| OmniVLA language | wizard / `--vla` | Passed to edge / full / remote as `--text-prompt` |
| `--stop-distance` | `go2_nav run` | Default 1.0 m |
| `--min-interval` | `go2_nav run` | Min seconds between stop evaluations |
| Velocity clamps | `server_client.py` | `MAX_LINEAR=0.3`, `MAX_ANGULAR=0.4` (remote) |
| Checkpoint / resume | `InferenceConfig` in `run_omnivla.py` | Default original / `120000` |
| Conda root | `GO2_CONDA_BASE` | Portable; no hardcoded miniforge path |

Hard stop: `Ctrl+C` on the driver and stack terminals.

## Isaac Sim

Pass `--sim` so the stack uses Isaac topic names. Ignore
`real_robot_SDKs/unitree_ros2/` and `Go2_Isaac_ros2/` unless you are working on
simulation internals.
