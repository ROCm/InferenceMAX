#!/usr/bin/env bash

# ========= Required Env Vars =========
# HF_TOKEN
# HF_HUB_CACHE
# MODEL
# PORT
# TP
# CONC
# MAX_MODEL_LEN
# EP_SIZE

set -x
echo "TP: $TP, CONC: $CONC, ISL: $ISL, OSL: $OSL, EP_SIZE: $EP_SIZE, DP_ATTENTION: $DP_ATTENTION"

# Calculate max-model-len based on ISL and OSL
if [ "$ISL" = "1024" ] && [ "$OSL" = "1024" ]; then
    CALCULATED_MAX_MODEL_LEN=""
else
    CALCULATED_MAX_MODEL_LEN=" --max-model-len 10240 "
fi

if [ "$EP_SIZE" -gt 1 ]; then
  EP=" --enable-expert-parallel"
else
  EP=" "
fi

# https://github.com/ROCm/ATOM/pull/119
if [ "$CONC" -gt 4 ]; then
  export ATOM_USE_TRITON_GEMM=1
else
  export ATOM_USE_TRITON_GEMM=1
  export ATOM_ENABLE_DS_INPUT_RMSNORM_QUANT_FUSION=0
fi

set -x
python3 -m atom.entrypoints.openai_server \
    --model $MODEL \
    --server-port $PORT \
    -tp $TP \
    --kv_cache_dtype fp8 \
    $CALCULATED_MAX_MODEL_LEN $EP 
