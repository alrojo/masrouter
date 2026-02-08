#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
PID_FILE="running_pids.txt"
NEMO_PORT=8000
QWEN_PORT=8001

echo ">>> Stopping AI Agent Servers..."

# ==============================================================================
# STEP 1: KILL BY PID FILE
# ==============================================================================
if [ -f "$PID_FILE" ]; then
    echo "Found PID file ($PID_FILE). Reading PIDs..."
    
    while read -r pid; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "Stopping PID $pid..."
            kill "$pid"
        else
            echo "PID $pid is not currently running or invalid."
        fi
    done < "$PID_FILE"

    # Wait a moment for graceful shutdown
    sleep 2
    
    # Remove the file
    rm "$PID_FILE"
    echo "Removed $PID_FILE."
else
    echo "No PID file found. Proceeding to port check..."
fi

# ==============================================================================
# STEP 2: FORCE CLEANUP BY PORT (FALLBACK)
# ==============================================================================
# Sometimes the PID file is missing or the process detached. 
# We check if anything is still listening on the specific ports.

kill_port() {
    local port=$1
    # Find PID listening on port
    local pid=$(lsof -t -i:$port 2>/dev/null)
    
    if [ ! -z "$pid" ]; then
        echo "WARNING: Port $port is still in use by PID $pid. Force killing..."
        kill -9 $pid
    else
        echo "Port $port is free."
    fi
}

echo "--- Verifying Ports ---"
kill_port $NEMO_PORT
kill_port $QWEN_PORT

echo ">>> All servers stopped."
