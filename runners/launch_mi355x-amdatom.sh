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
FRAMEWORK_SUFFIX=$([[ "$FRAMEWORK" == "atom" ]] && printf '_atom' || printf '')
FRAMEWORK_SUFFIX=$([[ "$FRAMEWORK" == "sglang" ]] && printf '_sglang' || printf '')
PORT=8888

server_name="bmk-server"
client_name="bmk-client"

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true

if [[ "$MODEL" == "amd/DeepSeek-R1-0528-MXFP4-Preview" || "$MODEL" == "deepseek-ai/DeepSeek-R1-0528" ]]; then
  if [[ "$OSL" == "8192" ]]; then
    #NUM_PROMPTS=$(( CONC * 20 ))
    export NUM_PROMPTS=$(( CONC * 2 )) # atom has no much compilation overhead for dsr1
  else
    #NUM_PROMPTS=$(( CONC * 50 ))
    export NUM_PROMPTS=$(( CONC * 10 )) # atom has no much compilation overhead for dsr1
  fi
else
  if [[ "$OSL" == "8192" ]]; then
    export NUM_PROMPTS=$(( CONC * 2 ))
  else
    export NUM_PROMPTS=$(( CONC * 10 ))
  fi
fi

# TODO: override
export NUM_PROMPTS=$(( CONC * 10 ))

set -x
docker pull $IMAGE
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | cut -d'@' -f2)
echo "The image digest is: $DIGEST"

set -x
docker run --rm --init --network host --shm-size=16g --name=$server_name \
--privileged --cap-add=CAP_SYS_ADMIN --device=/dev/kfd --device=/dev/dri --device=/dev/mem \
--cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
-v $HF_HUB_CACHE_MOUNT:$HF_HUB_CACHE \
-v $GITHUB_WORKSPACE:/workspace/ -w /workspace/ \
-e HF_TOKEN -e HF_HUB_CACHE -e MODEL -e TP -e CONC -e MAX_MODEL_LEN -e ISL -e OSL -e PORT=$PORT -e EP_SIZE -e DP_ATTENTION \
-e RESULT_FILENAME -e RANDOM_RANGE_RATIO -e NUM_PROMPTS \
--entrypoint=/bin/bash \
$IMAGE \
benchmarks/"${EXP_NAME%%_*}_${PRECISION}_mi355x${FRAMEWORK_SUFFIX}_docker.sh"

if ls gpucore.* 1> /dev/null 2>&1; then
  echo "gpucore files exist. not good"
  rm -f gpucore.*
fi

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true
