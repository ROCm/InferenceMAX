#!/usr/bin/env bash

# === Workflow-defined Env Vars ===
# IMAGE
# MODEL
# TP
# HF_HUB_CACHE
# ISL
# OSL
# MAX_MODEL_LEN
# RANDOM_RANGE_RATIO
# CONC
# GITHUB_WORKSPACE
# RESULT_FILENAME
# HF_TOKEN
# FRAMEWORK

HF_HUB_CACHE_MOUNT="/mnt/hf_hub_cache/"  # Temp solution
PORT=8888

# Determine framework suffix for benchmark script
FRAMEWORK_SUFFIX=$([[ "$FRAMEWORK" == "atom" ]] && printf '_atom' || printf '')

network_name="bmk-net"
server_name="bmk-server"
client_name="bmk-client"

# Cleanup: stop server container and remove network
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true
docker network rm $network_name 2>/dev/null || true

docker network create $network_name

if [[ "$MODEL" == "amd/DeepSeek-R1-0528-MXFP4-Preview" || "$MODEL" == "deepseek-ai/DeepSeek-R1-0528" ]]; then
  if [[ "$OSL" == "8192" ]]; then
    #NUM_PROMPTS=$(( CONC * 20 ))
    NUM_PROMPTS=$(( CONC * 2 )) # atom has no much compilation overhead for dsr1
  else
    #NUM_PROMPTS=$(( CONC * 50 ))
    NUM_PROMPTS=$(( CONC * 10 )) # atom has no much compilation overhead for dsr1
  fi
else
  if [[ "$OSL" == "8192" ]]; then
    NUM_PROMPTS=$(( CONC * 2 ))
  else
    NUM_PROMPTS=$(( CONC * 10 ))
  fi
fi

set -x
docker pull $IMAGE
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | cut -d'@' -f2)
echo "The image digest is: $DIGEST"

set -x
docker run --rm -d --ipc=host --shm-size=16g --network host --name=$server_name \
--privileged --cap-add=CAP_SYS_ADMIN --device=/dev/kfd --device=/dev/dri --device=/dev/mem \
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
-v $HF_HUB_CACHE_MOUNT:$HF_HUB_CACHE \
-v $GITHUB_WORKSPACE:/workspace/ -w /workspace/ \
-e HF_TOKEN -e HF_HUB_CACHE -e MODEL -e TP -e CONC -e MAX_MODEL_LEN -e PORT=$PORT -e EP_SIZE -e DP_ATTENTION \
-e ISL -e OSL \
--entrypoint=/bin/bash \
$IMAGE \
benchmarks/"${EXP_NAME%%_*}_${PRECISION}_mi355x${FRAMEWORK_SUFFIX}_docker.sh"

if ls gpucore.* 1> /dev/null 2>&1; then
  echo "gpucore files exist. not good"
  rm -f gpucore.*
fi

# Cleanup: stop server container and remove network
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true
docker network rm $network_name 2>/dev/null || true
