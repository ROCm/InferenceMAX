#!/usr/bin/env bash

# === Required Env Vars ===
# MODEL
# PORT
# TP
# CONC
# ISL
# OSL
# MAX_MODEL_LEN
# RANDOM_RANGE_RATIO
# RESULT_FILENAME
# NUM_PROMPTS

# Calculate max-model-len based on ISL and OSL
if [ "$ISL" = "1024" ] && [ "$OSL" = "1024" ]; then
    CALCULATED_MAX_MODEL_LEN=$((ISL + OSL + 20))
elif [ "$ISL" = "8192" ] || [ "$OSL" = "8192" ]; then
    CALCULATED_MAX_MODEL_LEN=$((ISL + OSL + 200))
else
    CALCULATED_MAX_MODEL_LEN=${MAX_MODEL_LEN:-10240}  
fi

#cat > config.yaml << EOF
#kv-cache-dtype: fp8
#compilation-config: '{"pass_config":{"fuse_allreduce_rms":true,"eliminate_noops":true}}'
#async-scheduling: true
#no-enable-prefix-caching: true
#max-cudagraph-capture-size: 2048
#max-num-batched-tokens: 8192
#max-model-len: $CALCULATED_MAX_MODEL_LEN
#EOF

cat > config.yaml << EOF
no-enable-prefix-caching: true
max-model-len: $CALCULATED_MAX_MODEL_LEN
block-size: 1
EOF

# Turn off docker specific optimizations 
#export VLLM_USE_AITER_UNIFIED_ATTENTION=1
#export VLLM_ROCM_USE_AITER_MHA=0
#export VLLM_ROCM_USE_AITER_FUSED_MOE_A16W4=1

SERVER_LOG=$(mktemp /tmp/server-XXXXXX.log)

set -x
vllm serve $MODEL --host 0.0.0.0 --port $PORT --config config.yaml \
--gpu-memory-utilization 0.9 --tensor-parallel-size $TP --max-num-seqs 512 \
--trust-remote-code \
--tokenizer-mode deepseek_v32 \
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
