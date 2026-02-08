#!/bin/bash

# ==============================================================================
# CONFIGURATION - HEAVY LOAD
# ==============================================================================
PORT=8000
NUM_PROMPTS=128       # Total requests
INPUT_LEN=1024         # Input tokens (Prefill)
OUTPUT_LEN=512         # Output tokens (Decode)
CONCURRENCY=32         # Concurrent users

trap "kill 0" EXIT

wait_for_server() {
    echo "Waiting for vLLM to be ready..."
    while ! curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT/health | grep -q "200"; do
        sleep 5
    done
    echo "Server is ready!"
}

# ==============================================================================
# 1. HEAVY BENCHMARK: NVIDIA Nemotron
# ==============================================================================
MODEL_1="deepseek-ai/DeepSeek-R1-0528-Qwen3-8B"
SERVED_NAME_1="deepseek"

echo "----------------------------------------------------------------"
echo "STARTING HEAVY LOAD TEST: $SERVED_NAME_1"
echo "----------------------------------------------------------------"

# Launch Server
vllm serve $MODEL_1 \
  --served-model-name $SERVED_NAME_1 \
  --max-num-seqs $CONCURRENCY \
  --max-model-len 131072 \
  --port $PORT \
  --trust-remote-code \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  > deepseek_heavy.log 2>&1 &

SERVER_PID=$!
wait_for_server

# Run Benchmark
# FIX: Added --tokenizer and --trust-remote-code
echo ">>> Generating ~1.5 Million Tokens..."
vllm bench serve \
  --model $SERVED_NAME_1 \
  --tokenizer $MODEL_1 \
  --trust-remote-code \
  --base-url http://localhost:$PORT \
  --dataset-name random \
  --random-input-len $INPUT_LEN \
  --random-output-len $OUTPUT_LEN \
  --num-prompts $NUM_PROMPTS \
  --max-concurrency $CONCURRENCY \
  --request-rate inf

# Cleanup
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
sleep 10

# ==============================================================================
# 2. HEAVY BENCHMARK: Qwen3
# ==============================================================================
MODEL_2="Qwen/Qwen3-4B-Instruct-2507-FP8"
SERVED_NAME_2="qwen3_4b"

echo "----------------------------------------------------------------"
echo "STARTING HEAVY LOAD TEST: $SERVED_NAME_2"
echo "----------------------------------------------------------------"

# Launch Server
vllm serve $MODEL_2 \
  --served-model-name $SERVED_NAME_2 \
  --max-model-len 32768 \
  --port $PORT \
  --trust-remote-code \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder > vllm_qwen_heavy.log 2>&1 &

SERVER_PID=$!
wait_for_server

# Run Benchmark
# FIX: Added --tokenizer and --trust-remote-code
echo ">>> Generating ~1.5 Million Tokens..."
vllm bench serve \
  --model $SERVED_NAME_2 \
  --tokenizer $MODEL_2 \
  --trust-remote-code \
  --base-url http://localhost:$PORT \
  --dataset-name random \
  --random-input-len $INPUT_LEN \
  --random-output-len $OUTPUT_LEN \
  --num-prompts $NUM_PROMPTS \
  --max-concurrency $CONCURRENCY \
  --request-rate inf

# Cleanup
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "Heavy Benchmark Complete."
