#!/usr/bin/env bash

# ========= Required Env Vars =========
# HF_TOKEN
# HF_HUB_CACHE
# MODEL
# PORT
# TP
# CONC
# MAX_MODEL_LEN
# DP_ATTENTION
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

if [[ "$DP_ATTENTION" == "true" ]]; then
  DP=" --enable-dp-attention "
else
  DP=" "
fi

SERVER_LOG=$(mktemp /tmp/server-XXXXXX.log)

set -x
python3 -m atom.entrypoints.openai_server \
    --model $MODEL \
    --server-port $PORT \
    -tp $TP \
    --kv_cache_dtype fp8 \
    $CALCULATED_MAX_MODEL_LEN $EP $DP \
> $SERVER_LOG 2>&1 &

SERVER_PID=$!

# Source benchmark utilities
source "$(dirname "$0")/benchmark_lib.sh"

# Wait for server to be ready
wait_for_server_ready --port "$PORT" --server-log "$SERVER_LOG" --server-pid "$SERVER_PID"

run_benchmark_serving \
    --model "$MODEL" \
    --port "$PORT" \
    --backend vllm \
    --input-len "$ISL" \
    --output-len "$OSL" \
    --random-range-ratio "$RANDOM_RANGE_RATIO" \
    --num-prompts "$NUM_PROMPTS" \
    --max-concurrency "$CONC" \
    --result-filename "$RESULT_FILENAME" \
    --result-dir /workspace/


