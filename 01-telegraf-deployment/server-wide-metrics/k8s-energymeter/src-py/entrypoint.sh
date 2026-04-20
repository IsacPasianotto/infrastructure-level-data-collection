#!/usr/bin/bash

# --- paths (adatta se necessario) ---

SCRIPT_PATH="/app/api.py"
CONF=/app/config/config.ini
LOG=/app/api_runtime.log

METRICS_URL="http://127.0.0.1:8080/metrics"

# check: is api.py already running?
is_running() {
  pgrep -f api.py >/dev/null 2>&1
}
# check: is /metrics endpoint up?
is_up() {
  curl -s --max-time 5 --fail "$METRICS_URL" >/dev/null 2>&1
}

# STEP 1. start api.py if not already running
if ! is_running; then
  nohup python "$SCRIPT_PATH" -c "$CONF" > "$LOG" 2>&1 &
fi

# STEP 2. wait a bit for /metrics to become available (max ~5s)
for _ in 1 2 3 4 5; do
  if is_up; then
    echo "API is up and running"
    break
  fi
  sleep 1
done

# once it is up, just wait indefinitely and every 3m check if it is still up
while true; do
  sleep 180
  if ! is_up; then
    echo "API is down, restarting..."
    # kill the old process if still running
    pkill -f api.py >/dev/null 2>&1
    # start a new one
    nohup python "$SCRIPT_PATH" -c "$CONF" > "$LOG" 2>&1 &
  fi
done