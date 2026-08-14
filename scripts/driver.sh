#!/usr/bin/env bash
# Launch the unofficial Go2 ROS 2 driver (native, sim conda env).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib.sh"

edgejudge_load_dotenv

if [[ -z "${ROBOT_IP:-}" ]]; then
  echo "ROBOT_IP is empty. Copy .env.example to .env and set ROBOT_IP, or export it." >&2
  exit 1
fi

if [[ -z "${CONN_TYPE:-}" ]]; then
  CONN_TYPE=webrtc
fi

edgejudge_init_conda
if ! edgejudge_conda_exists sim; then
  echo "conda env 'sim' not found. Run: make setup" >&2
  exit 1
fi

WS="${REPO_ROOT}/unofficial_sdk_unitree_go_2"
if [[ ! -f "${WS}/install/setup.bash" ]]; then
  echo "Missing ${WS}/install/setup.bash. Run: make setup" >&2
  exit 1
fi
if [[ ! -d "${WS}/install/go2_robot_sdk" ]]; then
  echo "Missing ${WS}/install/go2_robot_sdk. Run: make setup   (colcon did not install the driver package)" >&2
  exit 1
fi

echo "[driver] ROBOT_IP=${ROBOT_IP} CONN_TYPE=${CONN_TYPE}"

set +u
conda activate sim
# ROS setup.bash references unset variables; keep nounset off.
# shellcheck source=/dev/null
source "${WS}/install/setup.bash"
export ROBOT_IP CONN_TYPE
if ! command -v ros2 >/dev/null 2>&1; then
  echo "ros2 not found after activating sim and sourcing install/setup.bash." >&2
  echo "Re-run: bash goal_stop_judge/envs/install_sim_env.sh --update" >&2
  exit 1
fi
cd "${WS}"
exec ros2 launch go2_robot_sdk robot.launch.py nav2:=false slam:=false joystick:=false
