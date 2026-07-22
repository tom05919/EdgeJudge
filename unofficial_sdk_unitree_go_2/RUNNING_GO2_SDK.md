# Running the Unitree Go2 ROS 2 SDK

> **Full stop-judge + OmniVLA stack:** see [`../README.md`](../README.md)
> (`python go2_nav.py`). Recreate the `sim` env with
> `goal_stop_judge/envs/install_sim_env.sh` rather than ad-hoc packages.
>
> Canonical layout: colcon workspace at `unofficial_sdk_unitree_go_2`, then
> `source install/setup.bash` every shell. Set `ROBOT_IP` to **your** robot
> address (examples in this file and in `REAL_ROBOT_GO2.md` may differ).

This guide explains how to build and launch the unofficial Unitree Go2 ROS 2 SDK
inside the RoboStack conda environment (`sim`), plus the issues you may hit along
the way and how to fix them.

## 1. Environment overview

- **Workspace root:** `unofficial_sdk_unitree_go_2`
  (absolute path depends on where you cloned the workspace).
  - This is the **colcon workspace** (contains `build/`, `install/`, `log/`, `src/`).
  - `src/` holds the actual ROS packages (`go2_robot_sdk`, `go2_interfaces`, etc.)
    — typically a clone of [go2_ros2_sdk](https://github.com/abizovnuralem/go2_ros2_sdk).
- **ROS distro:** Humble, provided via **RoboStack** (conda), not system `/opt/ros`.
- **Conda env:** `sim` (resolve base with `GO2_CONDA_BASE` or `conda info --base`;
  do not hardcode `/root/miniforge3`).

> Directory layout:
> ```
> unofficial_sdk_unitree_go_2/   <- colcon workspace root (run colcon here)
> ├── RUNNING_GO2_SDK.md
> ├── build/
> ├── install/
> ├── log/
> └── src/                       <- ROS package sources (go2_ros2_sdk)
>     ├── go2_robot_sdk/
>     ├── go2_interfaces/
>     └── ...
> ```

## 2. One-time prerequisites

Activate the environment and confirm ROS is available through conda:

```bash
conda activate sim
echo "$CONDA_DEFAULT_ENV"   # -> sim
echo "$ROS_DISTRO"          # -> humble
which ros2                  # -> $CONDA_PREFIX/bin/ros2
```

Prefer recreating `sim` with `goal_stop_judge/envs/install_sim_env.sh`. If you
install packages by hand, use **mamba** (not `apt` — apt installs to `/opt/ros`,
which the conda `ros2` cannot see):

```bash
mamba install -c conda-forge -c robostack-humble \
  ros-humble-foxglove-bridge \
  ros-humble-slam-toolbox \
  ros-humble-navigation2 \
  ros-humble-nav2-bringup \
  ros-humble-pointcloud-to-laserscan \
  ros-humble-joy \
  ros-humble-teleop-twist-joy \
  ros-humble-twist-mux
```

Pin a compatible `setuptools` (see Debugging §B for why this matters):

```bash
pip install "setuptools<80" "packaging<25"
```

## 3. Build the workspace

Always build from the **colcon workspace root** (`unofficial_sdk_unitree_go_2`),
not from inside `src/`.

```bash
conda activate sim
cd unofficial_sdk_unitree_go_2   # from your workspace root

# Clean any stale build artifacts (important if the workspace was moved
# or built on a different machine / conda path)
rm -rf build install log

# Prefer a normal install. --symlink-install can fail with newer setuptools
# ("option --editable not recognized") on ament_python packages.
colcon build --packages-select go2_interfaces go2_robot_sdk
```

## 4. Run the SDK

Source the workspace overlay and launch:

```bash
source install/setup.bash

export ROBOT_IP="192.168.10.55"   # your robot's IP (comma-separate for multiple)
export CONN_TYPE="webrtc"        # or "cyclonedds"

ros2 launch go2_robot_sdk robot.launch.py
```

> You must re-run `conda activate sim` and `source install/setup.bash` in every
> new terminal.

---

## Debugging guide

These are the problems encountered while bringing the SDK up, with fixes.

### A. `local_setup.sh: No such file or directory`

**Cause:** sourcing the wrong path (e.g. an extra nested `src/`). After the
single-`src` layout, `install/` lives next to `src/` under
`unofficial_sdk_unitree_go_2/`.

**Fix:** source the setup script from the colcon workspace root:

```bash
cd unofficial_sdk_unitree_go_2
source install/setup.bash
```

### B. `colcon build` fails: `error: option --editable not recognized`

**Cause:** `setuptools >= 80` removed the legacy `setup.py develop`/`install`
commands that colcon uses for Python packages.

**Fix:** downgrade setuptools, then rebuild:

```bash
pip install "setuptools<80" "packaging<25"
rm -rf build install log
colcon build --packages-select go2_interfaces go2_robot_sdk
```

> Tip: watch out for the typo `rm -rf build installlog` — that does **not**
> remove `install` and `log`. Keep the spaces: `rm -rf build install log`.

### C. `Package 'go2_robot_sdk' not found ... searching: ['…/envs/sim']`

**Cause:** the workspace overlay was not sourced — ROS only sees the conda env,
not your built packages.

**Fix:**

```bash
source install/setup.bash   # from unofficial_sdk_unitree_go_2
ros2 pkg list | grep go2   # should list go2_robot_sdk, go2_interfaces
```

### D. `executable 'go2_driver_node' not found on the libexec directory ...`

**Cause:** the installed entry-point scripts had the wrong Python shebang
(another conda prefix) and/or were missing the execute bit — a sign the
`install/` tree was stale from another machine.

**Fix:** rebuild cleanly inside the current env (regenerates correct shebangs and
permissions):

```bash
cd unofficial_sdk_unitree_go_2
rm -rf build install log
colcon build --packages-select go2_interfaces go2_robot_sdk
source install/setup.bash
```

### E. `PackageNotFoundError: "package 'foxglove_bridge' not found"`

**Cause:** a dependency (Foxglove bridge, SLAM, Nav2, etc.) is not installed in
the conda env. `robot.launch.py` resolves `foxglove_bridge` at parse time, so
`foxglove:=false` will **not** avoid this.

**Fix:** install via mamba (see §2). Do **not** use `apt install
ros-humble-foxglove-bridge` — it installs into `/opt/ros` and is invisible to the
conda `ros2`.

---

## Quick start (every new terminal)

```bash
conda activate sim
cd unofficial_sdk_unitree_go_2
source install/setup.bash
export ROBOT_IP="192.168.x.x"   # your robot IP
export CONN_TYPE="webrtc"
ros2 launch go2_robot_sdk robot.launch.py
```

## Common gotchas checklist

- [ ] Run `colcon build` from `unofficial_sdk_unitree_go_2` (colcon root), **not** from `src/`.
- [ ] Use **mamba**, not `apt`, for ROS packages (RoboStack/conda environment).
- [ ] Keep `setuptools < 80` so colcon can build Python packages.
- [ ] `source install/setup.bash` in every new shell.
- [ ] If you copied or moved the workspace, `rm -rf build install log` and rebuild
      so paths/shebangs are regenerated.

## Known issues

- `coco_detector/setup.py` has a malformed console-script entry point:
  `coco_detector_node = coco_detector.coco_detector_node` is missing the `:main`
  suffix. It should be `coco_detector.coco_detector_node:main`. If that node fails
  to launch, this is the cause.
