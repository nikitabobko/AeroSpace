#!/bin/bash

# Performance comparison script for AeroSpace
# Tests both original and optimized versions

echo "AeroSpace Performance Comparison Test"
echo "===================================="
echo

# Configuration
ITERATIONS=50
WORKSPACE_SWITCHES=100
FOCUS_OPERATIONS=50

# Dynamic path detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Find debug build paths dynamically
find_debug_app() {
    # Try Xcode DerivedData locations
    local xcode_derived="$(xcode-select -p 2>/dev/null)/../.."
    if [[ -d "$xcode_derived" ]]; then
        find "$xcode_derived" -name "AeroSpace-Debug.app" -path "*/Debug/*" 2>/dev/null | head -1
    fi
}

DEBUG_APP_PATH="$(find_debug_app)"
if [[ -n "$DEBUG_APP_PATH" ]]; then
    DEBUG_PATH="$DEBUG_APP_PATH/Contents/MacOS/AeroSpace-Debug"
else
    DEBUG_PATH="" # Will be detected later or fail gracefully
fi

# Find debug CLI
if [[ -f "$PROJECT_ROOT/.build/arm64-apple-macosx/debug/aerospace" ]]; then
    DEBUG_CLI="$PROJECT_ROOT/.build/arm64-apple-macosx/debug/aerospace"
elif [[ -f "$PROJECT_ROOT/.build/x86_64-apple-macosx/debug/aerospace" ]]; then
    DEBUG_CLI="$PROJECT_ROOT/.build/x86_64-apple-macosx/debug/aerospace"
else
    DEBUG_CLI="" # Will be detected later or fail gracefully
fi

ORIGINAL_PATH="/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
ORIGINAL_CLI="/opt/homebrew/bin/aerospace"

# Function to get CPU usage
get_cpu_usage() {
    local pid=$1
    local duration=$2
    local samples=$3
    
    # Collect CPU samples
    local total=0
    for i in $(seq 1 $samples); do
        cpu=$(ps -p $pid -o %cpu | tail -1 | tr -d ' ')
        total=$(echo "$total + $cpu" | bc)
        sleep $(echo "scale=2; $duration / $samples" | bc)
    done
    
    echo "scale=2; $total / $samples" | bc
}

# Function to get memory usage
get_memory_usage() {
    local pid=$1
    vmmap $pid 2>/dev/null | grep "Physical footprint" | awk '{print $3}' | sed 's/M//'
}

# Function to time a command (using python for precise timing)
time_command() {
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
print(f'{(end - start) / 1000000:.3f}')
" "$@"
}

# Function to run workspace switching test
test_workspace_switching() {
    local cli=$1
    echo "  Running workspace switching test..."
    
    local total_time=0
    for i in $(seq 1 $WORKSPACE_SWITCHES); do
        time1=$(time_command $cli workspace 1)
        time2=$(time_command $cli workspace 2)
        total_time=$(echo "$total_time + $time1 + $time2" | bc)
    done
    
    echo "scale=3; $total_time / ($WORKSPACE_SWITCHES * 2)" | bc
}

# Function to run window focus test
test_window_focus() {
    local cli=$1
    echo "  Running window focus test..."
    
    # Get list of windows
    local windows=($($cli list-windows --all --format "%{window-id}" 2>/dev/null | head -$FOCUS_OPERATIONS))
    
    local total_time=0
    local count=0
    for window_id in "${windows[@]}"; do
        if [ ! -z "$window_id" ]; then
            time=$(time_command $cli focus --window-id "$window_id")
            total_time=$(echo "$total_time + $time" | bc)
            count=$((count + 1))
        fi
    done
    
    if [ $count -gt 0 ]; then
        echo "scale=3; $total_time / $count" | bc
    else
        echo "0"
    fi
}

# Function to run a complete test suite
run_test_suite() {
    local name=$1
    local binary=$2
    local cli=$3
    
    echo "Testing: $name"
    echo "----------------------------------------"
    
    # Kill any existing AeroSpace process
    killall AeroSpace 2>/dev/null
    killall AeroSpace-Debug 2>/dev/null
    sleep 2
    
    # Start the version we want to test
    echo "  Starting $name..."
    "$binary" &
    local pid=$!
    sleep 3  # Give it time to start
    
    # Initial memory measurement
    echo "  Measuring initial memory usage..."
    local initial_memory=$(get_memory_usage $pid)
    
    # CPU usage during idle
    echo "  Measuring idle CPU usage..."
    local idle_cpu=$(get_cpu_usage $pid 5 5)
    
    # Workspace switching test
    local avg_workspace_time=$(test_workspace_switching "$cli")
    echo "  Measuring CPU during workspace switching..."
    local workspace_cpu=$(get_cpu_usage $pid 5 5)
    
    # Window focus test
    local avg_focus_time=$(test_window_focus "$cli")
    echo "  Measuring CPU during window focus..."
    local focus_cpu=$(get_cpu_usage $pid 5 5)
    
    # Stress test - rapid operations
    echo "  Running stress test..."
    for i in {1..20}; do
        $cli workspace $((i % 9 + 1)) 2>/dev/null
        $cli list-windows --all >/dev/null 2>&1
    done
    local stress_cpu=$(get_cpu_usage $pid 5 5)
    
    # Final memory measurement
    echo "  Measuring final memory usage..."
    local final_memory=$(get_memory_usage $pid)
    
    # Kill the process
    kill $pid 2>/dev/null
    sleep 2
    
    # Output results
    echo
    echo "Results for $name:"
    echo "  Idle CPU Usage: ${idle_cpu}%"
    echo "  Workspace Switch CPU: ${workspace_cpu}%"
    echo "  Window Focus CPU: ${focus_cpu}%"
    echo "  Stress Test CPU: ${stress_cpu}%"
    echo "  Initial Memory: ${initial_memory}M"
    echo "  Final Memory: ${final_memory}M"
    echo "  Avg Workspace Switch Time: ${avg_workspace_time}ms"
    echo "  Avg Window Focus Time: ${avg_focus_time}ms"
    echo
    
    # Return results as a string
    echo "$idle_cpu|$workspace_cpu|$focus_cpu|$stress_cpu|$initial_memory|$final_memory|$avg_workspace_time|$avg_focus_time"
}

# Main test execution
echo "Note: This test will kill and restart AeroSpace multiple times."
echo "Please save any work and close unnecessary applications."
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check if original AeroSpace exists
if [ ! -f "$ORIGINAL_PATH" ]; then
    echo "Error: Original AeroSpace not found at $ORIGINAL_PATH"
    echo "Please install AeroSpace via Homebrew first: brew install --cask nikitabobko/tap/aerospace"
    exit 1
fi

# Check if debug build exists
if [[ -z "$DEBUG_PATH" || ! -f "$DEBUG_PATH" ]]; then
    echo "Error: Debug app binary not found"
    echo "Please build the project with Xcode first"
    echo "Expected location pattern: */DerivedData/AeroSpace-*/Build/Products/Debug/AeroSpace-Debug.app/Contents/MacOS/AeroSpace-Debug"
    exit 1
fi

if [[ -z "$DEBUG_CLI" || ! -f "$DEBUG_CLI" ]]; then
    echo "Error: Debug CLI not found"
    echo "Please build the CLI with: swift build --configuration debug --product aerospace"
    exit 1
fi

# Run tests for original version
echo
ORIGINAL_RESULTS=$(run_test_suite "Original AeroSpace" "$ORIGINAL_PATH" "$ORIGINAL_CLI" | tail -1)

# Run tests for optimized version
echo
OPTIMIZED_RESULTS=$(run_test_suite "Optimized AeroSpace (Debug)" "$DEBUG_PATH" "$DEBUG_CLI" | tail -1)

# Parse results
IFS='|' read -r orig_idle orig_workspace orig_focus orig_stress orig_init_mem orig_final_mem orig_ws_time orig_focus_time <<< "$ORIGINAL_RESULTS"
IFS='|' read -r opt_idle opt_workspace opt_focus opt_stress opt_init_mem opt_final_mem opt_ws_time opt_focus_time <<< "$OPTIMIZED_RESULTS"

# Calculate improvements
echo
echo "Performance Comparison Summary"
echo "=============================="
echo
echo "CPU Usage Improvements:"
idle_improvement=$(echo "scale=1; (($orig_idle - $opt_idle) / $orig_idle) * 100" | bc 2>/dev/null || echo "0")
workspace_improvement=$(echo "scale=1; (($orig_workspace - $opt_workspace) / $orig_workspace) * 100" | bc 2>/dev/null || echo "0")
focus_improvement=$(echo "scale=1; (($orig_focus - $opt_focus) / $orig_focus) * 100" | bc 2>/dev/null || echo "0")
stress_improvement=$(echo "scale=1; (($orig_stress - $opt_stress) / $orig_stress) * 100" | bc 2>/dev/null || echo "0")

echo "  Idle: ${orig_idle}% -> ${opt_idle}% (${idle_improvement}% improvement)"
echo "  Workspace Switching: ${orig_workspace}% -> ${opt_workspace}% (${workspace_improvement}% improvement)"
echo "  Window Focus: ${orig_focus}% -> ${opt_focus}% (${focus_improvement}% improvement)"
echo "  Stress Test: ${orig_stress}% -> ${opt_stress}% (${stress_improvement}% improvement)"

echo
echo "Memory Usage:"
echo "  Initial: ${orig_init_mem}M -> ${opt_init_mem}M"
echo "  Final: ${orig_final_mem}M -> ${opt_final_mem}M"

echo
echo "Response Times:"
ws_time_improvement=$(echo "scale=1; (($orig_ws_time - $opt_ws_time) / $orig_ws_time) * 100" | bc 2>/dev/null || echo "0")
focus_time_improvement=$(echo "scale=1; (($orig_focus_time - $opt_focus_time) / $orig_focus_time) * 100" | bc 2>/dev/null || echo "0")

echo "  Workspace Switch: ${orig_ws_time}ms -> ${opt_ws_time}ms (${ws_time_improvement}% faster)"
echo "  Window Focus: ${orig_focus_time}ms -> ${opt_focus_time}ms (${focus_time_improvement}% faster)"

echo
echo "Test completed at: $(date)"

# Restart the debug build since that's what was running
echo
echo "Restarting optimized debug build..."
"$DEBUG_PATH" &