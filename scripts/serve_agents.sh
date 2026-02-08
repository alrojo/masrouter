#!/bin/bash

# ==============================================================================
# CONFIGURATION - SINGLE H100 80GB (LIGHTWEIGHT MODE)
# ==============================================================================
export CUDA_VISIBLE_DEVICES=0

# Ports
REASONING_PORT=8000
CODER_PORT=8001

# Model IDs
# Note: Ensure "DeepSeek-R1-0528-Qwen3-8B" is the correct path in your HF cache or directory
REASONING_MODEL="deepseek-ai/DeepSeek-R1-0528-Qwen3-8B"
CODER_MODEL="Qwen/Qwen3-4B-Instruct-2507-FP8"

# Log Files
LOG_REASONING="log_deepseek.log"
LOG_CODER="log_qwen_coder.log"
PID_FILE="running_pids.txt"

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================
if [ -f "$PID_FILE" ]; then
    echo "ERROR: $PID_FILE exists. Servers might already be running."
    echo "Run './kill_agents.sh' first."
    exit 1
fi

# ==============================================================================
# START SERVER 1: DEEPSEEK REASONING (Port 8000)
# ==============================================================================
# Math: 8B params (BF16) = ~16GB VRAM.
# We allocate 40% of 80GB = 32GB.
# This gives ~16GB for weights + 16GB for KV Cache (massive context for 8B).

echo ">>> Starting DeepSeek R1 (Reasoning) on Port $REASONING_PORT..."

# Note: Removed Nemotron-specific reasoning parsers. 
# DeepSeek R1 usually handles <think> tags natively in its chat template.

nohup vllm serve $REASONING_MODEL \
  --served-model-name deepseek_reasoner \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.50 \
  --port $REASONING_PORT \
  --trust-remote-code \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  > $LOG_REASONING 2>&1 &

R1_PID=$!
echo $R1_PID >> $PID_FILE
echo "DeepSeek PID: $R1_PID (Alloc: 40GB)"

# Wait for DeepSeek to initialize
echo "Waiting 30s for DeepSeek to load..."
sleep 30

# ==============================================================================
# START SERVER 2: QWEN3 CODER (Port 8001)
# ==============================================================================
# Math: 4B params (FP8) = ~5GB VRAM.
# We allocate 20% of 80GB = 16GB.
# Plenty of room.

echo ">>> Starting Qwen3 Coder on Port $CODER_PORT..."

nohup vllm serve $CODER_MODEL \
  --served-model-name qwen3_coder \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.40 \
  --kv-cache-dtype fp8 \
  --port $CODER_PORT \
  --trust-remote-code \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  > $LOG_CODER 2>&1 &

CODER_PID=$!
echo $CODER_PID >> $PID_FILE
echo "Qwen3 Coder PID: $CODER_PID (Alloc: 32GB)"

# ==============================================================================
# HEALTH CHECK
# ==============================================================================
echo "----------------------------------------------------------------"
echo "Waiting for services to become ready..."
echo "----------------------------------------------------------------"

check_health() {
    url=$1
    name=$2
    while ! curl -s -o /dev/null -w "%{http_code}" $url/health | grep -q "200"; do
        echo "Waiting for $name..."
        sleep 5
    done
    echo "SUCCESS: $name is ready at $url"
}

check_health "http://localhost:$REASONING_PORT" "DeepSeek R1"
check_health "http://localhost:$CODER_PORT" "Qwen3 Coder"

echo "----------------------------------------------------------------"
echo "CLUSTER READY (Shared H100)"
echo "Memory Allocation: ~90% of GPU"
echo "----------------------------------------------------------------"
