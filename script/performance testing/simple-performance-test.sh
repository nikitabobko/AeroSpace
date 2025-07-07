#!/bin/bash

# Simple performance test for currently running AeroSpace
# Does not kill/restart the process

echo "AeroSpace Performance Test (Simple)"
echo "=================================="
echo

# Detect which version is running
PID=$(pgrep -x "AeroSpace-Debug" || pgrep -x "AeroSpace")
if [ -z "$PID" ]; then
    echo "Error: AeroSpace is not running!"
    exit 1
fi

PROCESS_NAME=$(ps -p $PID -o comm= | xargs basename)
echo "Testing: $PROCESS_NAME (PID: $PID)"
echo

# Determine CLI path based on running version
if [[ "$PROCESS_NAME" == "AeroSpace-Debug" ]]; then
    # Try to find the debug CLI binary dynamically
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    
    # Look for the debug CLI in common locations
    if [[ -f "$PROJECT_ROOT/.build/arm64-apple-macosx/debug/aerospace" ]]; then
        CLI="$PROJECT_ROOT/.build/arm64-apple-macosx/debug/aerospace"
    elif [[ -f "$PROJECT_ROOT/.build/x86_64-apple-macosx/debug/aerospace" ]]; then
        CLI="$PROJECT_ROOT/.build/x86_64-apple-macosx/debug/aerospace"
    else
        echo "Error: Debug CLI not found. Please build with: swift build --configuration debug --product aerospace"
        exit 1
    fi
    VERSION="Optimized Debug Build"
else
    CLI="/opt/homebrew/bin/aerospace"
    VERSION="Original Release"
fi

echo "Version: $VERSION"
echo "CLI: $CLI"
echo

# Function to measure CPU over time
measure_cpu() {
    local duration=$1
    local samples=10
    local total=0
    
    for i in $(seq 1 $samples); do
        cpu=$(ps -p $PID -o %cpu | tail -1 | tr -d ' ')
        total=$(echo "$total + $cpu" | bc)
        sleep $(echo "scale=2; $duration / $samples" | bc)
    done
    
    echo "scale=2; $total / $samples" | bc
}

# Function to time commands (using python for precise timing)
time_ms() {
    python3 -c "
import time
import subprocess
import sys
start = time.time_ns()
try:
    subprocess.run(sys.argv[1:], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
except:
    pass
end = time.time_ns()
print(f'{(end - start) / 1000000:.1f}')
" "$@"
}

# Initial measurements
echo "1. Baseline Measurements"
echo "------------------------"
echo -n "  Initial memory usage: "
vmmap $PID 2>/dev/null | grep "Physical footprint" | awk '{print $3}'

echo -n "  Idle CPU usage (5s avg): "
idle_cpu=$(measure_cpu 5)
echo "${idle_cpu}%"
echo

# Test 1: Workspace switching
echo "2. Workspace Switching Test"
echo "---------------------------"
echo "  Performing 50 workspace switches..."

ws_times=()
start_time=$(date +%s)
for i in {1..25}; do
    time1=$(time_ms $CLI workspace 1)
    time2=$(time_ms $CLI workspace 2)
    ws_times+=("$time1" "$time2")
done
end_time=$(date +%s)
total_ws_time=$((end_time - start_time))

# Calculate average
total=0
for t in "${ws_times[@]}"; do
    total=$(echo "$total + $t" | bc)
done
avg_ws_time=$(echo "scale=1; $total / ${#ws_times[@]}" | bc)

echo "  Average switch time: ${avg_ws_time}ms"
echo -n "  CPU during switching: "
switching_cpu=$(ps -p $PID -o %cpu | tail -1 | tr -d ' ')
echo "${switching_cpu}%"
echo

# Test 2: Window operations
echo "3. Window Operations Test"
echo "-------------------------"
echo "  Getting window list..."
windows=($($CLI list-windows --all --format "%{window-id}" 2>/dev/null | head -20))
echo "  Found ${#windows[@]} windows"

if [ ${#windows[@]} -gt 0 ]; then
    echo "  Performing focus operations..."
    focus_times=()
    for window_id in "${windows[@]:0:10}"; do
        if [ ! -z "$window_id" ]; then
            time=$(time_ms $CLI focus --window-id "$window_id")
            focus_times+=("$time")
        fi
    done
    
    # Calculate average
    total=0
    count=0
    for t in "${focus_times[@]}"; do
        if [ ! -z "$t" ]; then
            total=$(echo "$total + $t" | bc)
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        avg_focus_time=$(echo "scale=1; $total / $count" | bc)
        echo "  Average focus time: ${avg_focus_time}ms"
    fi
fi

echo -n "  CPU during operations: "
operations_cpu=$(ps -p $PID -o %cpu | tail -1 | tr -d ' ')
echo "${operations_cpu}%"
echo

# Test 3: List commands performance
echo "4. List Commands Test"
echo "--------------------"
list_times=()
echo "  Testing list commands..."

time1=$(time_ms $CLI list-windows --all)
echo "  list-windows --all: ${time1}ms"
list_times+=("$time1")

time2=$(time_ms $CLI list-workspaces --all)
echo "  list-workspaces --all: ${time2}ms"
list_times+=("$time2")

time3=$(time_ms $CLI list-monitors)
echo "  list-monitors: ${time3}ms"
list_times+=("$time3")

time4=$(time_ms $CLI list-apps)
echo "  list-apps: ${time4}ms"
list_times+=("$time4")
echo

# Test 4: Stress test
echo "5. Stress Test"
echo "--------------"
echo "  Running rapid operations for 10 seconds..."
stress_start=$(date +%s)
count=0
while [ $(($(date +%s) - stress_start)) -lt 10 ]; do
    $CLI workspace $((count % 4 + 1)) >/dev/null 2>&1
    $CLI list-windows --all >/dev/null 2>&1
    count=$((count + 1))
done
echo "  Completed $count operations"

echo -n "  Peak CPU during stress: "
stress_cpu=$(measure_cpu 2)
echo "${stress_cpu}%"
echo

# Final measurements
echo "6. Final Measurements"
echo "--------------------"
echo -n "  Final memory usage: "
vmmap $PID 2>/dev/null | grep "Physical footprint" | awk '{print $3}'

echo -n "  Post-test CPU (5s avg): "
final_cpu=$(measure_cpu 5)
echo "${final_cpu}%"
echo

# Summary
echo "Test Summary"
echo "============"
echo "Version: $VERSION"
echo "Process: $PROCESS_NAME"
echo ""
echo "CPU Usage:"
echo "  Idle: ${idle_cpu}%"
echo "  During operations: ${operations_cpu}%"
echo "  During stress: ${stress_cpu}%"
echo ""
echo "Response Times:"
echo "  Workspace switch: ${avg_ws_time}ms avg"
if [ ! -z "$avg_focus_time" ]; then
    echo "  Window focus: ${avg_focus_time}ms avg"
fi
echo ""
echo "List Command Performance:"
for i in "${!list_times[@]}"; do
    case $i in
        0) echo "  list-windows: ${list_times[$i]}ms";;
        1) echo "  list-workspaces: ${list_times[$i]}ms";;
        2) echo "  list-monitors: ${list_times[$i]}ms";;
        3) echo "  list-apps: ${list_times[$i]}ms";;
    esac
done

echo
echo "Test completed at: $(date)"
echo
echo "Note: For comparison, run this test with both the original"
echo "and optimized versions of AeroSpace."