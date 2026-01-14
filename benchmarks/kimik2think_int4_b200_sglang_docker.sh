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

nvidia-smi

# To improve CI stability, we patch this helper function to prevent a race condition that
# happens 1% of the time. ref: https://github.com/flashinfer-ai/flashinfer/pull/1779
# Turn off docker specific optimizations 
#sed -i '102,108d' /usr/local/lib/python3.12/dist-packages/flashinfer/jit/cubin_loader.py

SERVER_LOG=$(mktemp /tmp/server-XXXXXX.log)

set -x
python3 -m sglang.launch_server --model-path $MODEL --host 0.0.0.0 --port $PORT --trust-remote-code \
--tensor-parallel-size=$TP --data-parallel-size=1 \
--cuda-graph-max-bs 256 --max-running-requests 256 --mem-fraction-static 0.9 \
--ep-size $EP_SIZE \
--disable-radix-cache > $SERVER_LOG 2>&1 &

SERVER_PID=$!

# Source benchmark utilities
source "$(dirname "$0")/benchmark_lib.sh"

# Wait for server to be ready
wait_for_server_ready --port "$PORT" --server-log "$SERVER_LOG" --server-pid "$SERVER_PID"

pip install -q datasets pandas

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
