#!/usr/bin/env bash
HF_HUB_CACHE_MOUNT="/mnt/hf_hub_cache/"  # Temp solution

MODEL_CODE="${EXP_NAME%%_*}"
FRAMEWORK_SUFFIX=$(
  [[ "$FRAMEWORK" == "atom" ]] && printf '_atom' ||
  [[ "$FRAMEWORK" == "sglang" ]] && printf '_sglang' ||
  printf ''
)
SPEC_SUFFIX=$([[ "$SPEC_DECODING" == "mtp" ]] && printf '_mtp' || printf '')

server_name="bmk-server"

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true

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
-e HF_TOKEN \
-e HF_HUB_CACHE \
-e MODEL \
-e TP \
-e CONC \
-e ISL \
-e OSL \
-e RANDOM_RANGE_RATIO \
-e RESULT_FILENAME \
-e EP_SIZE \
-e DP_ATTENTION \
--entrypoint=/bin/bash \
$IMAGE \
benchmarks/${MODEL_CODE}_${PRECISION}_mi355x${FRAMEWORK_SUFFIX}${SPEC_SUFFIX}.sh

if ls gpucore.* 1> /dev/null 2>&1; then
  echo "gpucore files exist. not good"
  rm -f gpucore.*
fi

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true
