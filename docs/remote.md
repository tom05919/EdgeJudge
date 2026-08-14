# Remote full OmniVLA (ZeroMQ)

Use this when the Go2 PC cannot host the full OmniVLA checkpoint. The robot PC
still runs the stop judge (`perception`) and a thin ZMQ client; the GPU host
runs the model (`omnivla` env).

On the GPU host you need the EdgeJudge tree (or at least `omni-VLA/` with
`omnivla-original` weights), `make setup-full`, and `make weights-full`.

## GPU host

```bash
make serve
# default bind tcp://*:5555
# extra flags: make serve SERVE_ARGS='--bind tcp://*:5555'
```

Equivalent:

```bash
conda activate omnivla
cd omni-VLA
python inference/run_omnivla.py --mode serve --bind tcp://*:5555
```

Or from the robot-stack CLI (still on the GPU host, `omnivla` env via conda):

```bash
python goal_stop_judge/go2_nav.py serve --bind tcp://*:5555
```

Open TCP port 5555 on the GPU host firewall.

## Robot PC

Driver in terminal 1 ([real_robot.md](real_robot.md)). Then:

```bash
./scripts/nav.sh run --sam "Human." --vla "go to the human with white shirt" --nav remote --endpoint tcp://GPU_HOST_IP:5555
```

In the wizard, choose **remote** and set `tcp://<gpu-host-ip>:5555` — not
`localhost` unless the server is on the same machine.

The client lives in `goal_stop_judge/server_client.py` (`perception` env).
Timeouts usually mean the serve process is down, port 5555 is closed, or the
endpoint still points at `localhost`.
