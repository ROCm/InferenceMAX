#!/usr/bin/bash
HF_HUB_CACHE_MOUNT="/data/models/hf_hub_cache/"

MODEL_CODE="${EXP_NAME%%_*}"
FRAMEWORK_SUFFIX=$([[ "$FRAMEWORK" == "trt" ]] && printf '_trt' || printf '')
SPEC_SUFFIX=$([[ "$SPEC_DECODING" == "mtp" ]] && printf '_mtp' || printf '')

server_name="bmk-server"

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true

set -x
docker run --rm --network=host --name=$server_name \
--runtime=nvidia --gpus=all --ipc=host --privileged --shm-size=16g --ulimit memlock=-1 --ulimit stack=67108864 \
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
-e PYTHONPYCACHEPREFIX=/tmp/pycache/ -e TORCH_CUDA_ARCH_LIST="9.0" -e CUDA_DEVICE_ORDER=PCI_BUS_ID -e CUDA_VISIBLE_DEVICES="0,1,2,3,4,5,6,7" \
--entrypoint=/bin/bash \
$IMAGE \
benchmarks/${MODEL_CODE}_${PRECISION}_b200${FRAMEWORK_SUFFIX}${SPEC_SUFFIX}.sh

# Cleanup: stop server container 
docker stop $server_name 2>/dev/null || true
docker rm $server_name 2>/dev/null || true
