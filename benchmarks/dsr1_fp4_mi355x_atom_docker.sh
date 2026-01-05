#!/usr/bin/env bash

# ========= Required Env Vars =========
# HF_TOKEN
# HF_HUB_CACHE
# MODEL
# PORT
# TP
# CONC
# MAX_MODEL_LEN

# Calculate max-model-len based on ISL and OSL
if [[ "$ISL" == "1024" ]] && [[ "$OSL" == "1024" ]]; then
    CALCULATED_MAX_MODEL_LEN=""
else
    CALCULATED_MAX_MODEL_LEN=" --max-model-len 10240 "
fi

set -x

# 3. AITER & vLLM Feature Flags
export VLLM_USE_AITER=1
export SAFETENSORS_FAST_GPU=1
export TOKENIZERS_PARALLELISM=false

# 4. Low-level Performance Tuning
# Forces kernel arguments into device memory for lower launch latency
export HIP_FORCE_DEV_KERNARG=1

# 5. Ray & Multi-GPU Execution Settings
# Prevents Ray from overriding device visibility logic
export RAY_EXPERIMENTAL_NOSET_ROCR_VISIBLE_DEVICES=1
export RAY_EXPERIMENTAL_NOSET_HIP_VISIBLE_DEVICES=1

python3 -m atom.entrypoints.openai_server \
    --model $MODEL \
    --server-port $PORT \
    -tp $TP \
    --kv_cache_dtype fp8 $CALCULATED_MAX_MODEL_LEN
