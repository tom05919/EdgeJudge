# Docker (EdgeJudge)

This repo ships **Dockerfiles + Compose** so you can **build** containers locally.
We do **not** commit a pre-built image (no `.tar` / Hub blob in git).

```bash
# From the EdgeJudge repo root — builds from docker/Dockerfile.go2
export ROBOT_IP=192.168.x.x
docker compose -f docker/docker-compose.yml up --build go2_driver
```

| Build target | Compose service | Purpose |
|--------------|-----------------|--------|
| `docker/Dockerfile.go2` → tag `edgejudge-go2` | `go2_driver` | Unitree Go2 ROS 2 driver |
| `docker/Dockerfile` → tag `edgejudge:dev` | `stack-dev` | CUDA + Miniforge shell for the full stack |

Weights and the three conda envs are **not** baked into the build (too large).
Use `stack-dev`, mount the repo, and run `make setup` / `make weights` from
the EdgeJudge root (see [SETUP.md](../SETUP.md)).

## Prerequisites

- Docker Engine + Compose v2
- For `stack-dev` / GPU: [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- Submodules initialized (`git submodule update --init --recursive`)

All commands below are run from the **EdgeJudge repo root** (parent of `docker/`).

## Go2 driver (build from Dockerfile)

```bash
export ROBOT_IP=192.168.x.x          # required
export CONN_TYPE=webrtc              # or cyclonedds

docker compose -f docker/docker-compose.yml up --build go2_driver
```

Equivalent manual build/run:

```bash
docker build -f docker/Dockerfile.go2 -t edgejudge-go2:latest .
docker run --rm --network host --privileged \
  -e ROBOT_IP="$ROBOT_IP" -e CONN_TYPE=webrtc \
  edgejudge-go2:latest
```

## Full-stack dev shell (build from Dockerfile)

```bash
docker compose -f docker/docker-compose.yml --profile dev run --rm --build stack-dev
```

Inside the container:

```bash
cd /workspace
make setup                 # or: make setup-full
make weights
make smoke                 # optional, no robot
# Track B:
# make driver              # or use the go2_driver Compose service instead
make nav
```

Clone UniDepth / Grounded-SAM-2 / HF weights on the **host** (or inside the
mount) via `make setup` / `make weights` so they persist. Do not bake them into
the image.

## Files in this folder

| File | Role |
|------|------|
| `Dockerfile` | Recipe for CUDA + Miniforge (`edgejudge:dev`) |
| `Dockerfile.go2` | Recipe for ROS Humble Go2 driver (`edgejudge-go2`) |
| `docker-compose.yml` | `go2_driver` + optional `stack-dev` |
| `entrypoint-dev.sh` / `entrypoint-go2.sh` | Shell setup |
| `../.dockerignore` | Keeps weights/artifacts out of the build context |
