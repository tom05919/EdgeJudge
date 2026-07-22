# EdgeJudge stack development image: CUDA + Miniforge.
# Build from the EdgeJudge repo root:
#   docker build -f docker/Dockerfile -t edgejudge:dev .
#
# This image does NOT bake in conda envs or model weights (multi-GB).
# Mount the repo and run goal_stop_judge/envs/install_*_env.sh inside.

ARG CUDA_IMAGE=nvidia/cuda:12.6.0-devel-ubuntu22.04
FROM ${CUDA_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    GO2_CONDA_BASE=/opt/miniforge3 \
    PATH=/opt/miniforge3/bin:$PATH

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    git-lfs \
    build-essential \
    cmake \
    wget \
    vim \
    tmux \
    libgl1 \
    libglib2.0-0 \
    libportaudio2 \
    portaudio19-dev \
    && rm -rf /var/lib/apt/lists/*

# Miniforge (conda + mamba)
ARG MINIFORGE_VERSION=24.11.2-1
RUN curl -fsSL \
    "https://github.com/conda-forge/miniforge/releases/download/${MINIFORGE_VERSION}/Miniforge3-${MINIFORGE_VERSION}-Linux-x86_64.sh" \
    -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge3 \
    && rm /tmp/miniforge.sh \
    && /opt/miniforge3/bin/conda clean -afy

WORKDIR /workspace
COPY docker/entrypoint-dev.sh /usr/local/bin/edgejudge-entrypoint.sh
RUN chmod +x /usr/local/bin/edgejudge-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/edgejudge-entrypoint.sh"]
CMD ["bash"]
