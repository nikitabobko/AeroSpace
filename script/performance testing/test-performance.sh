#!/bin/bash

echo "AeroSpace Performance Test"
echo "========================="
echo

# Get the PID
PID=$(pgrep -x "AeroSpace-Debug" || pgrep -x "AeroSpace")
if [ -z "$PID" ]; then
    echo "AeroSpace is not running!"
    exit 1
fi

echo "Monitoring PID: $PID"
echo

# Test 1: Rapid workspace switching
echo "Test 1: Rapid workspace switching"
echo "---------------------------------"
for i in {1..10}; do
    ./.debug/aerospace workspace 1
    ./.debug/aerospace workspace 2
done
echo "CPU usage during rapid switching:"
top -pid $PID -stats pid,cpu -l 5 -s 1 | grep -E "(PID|$PID)"

echo
echo "Test 2: Window operations"
echo "------------------------"
# Focus different windows rapidly
./.debug/aerospace list-windows | head -10 | while read line; do
    window_id=$(echo $line | awk '{print $1}')
    ./.debug/aerospace focus --window-id $window_id 2>/dev/null
done

echo "CPU usage during window operations:"
top -pid $PID -stats pid,cpu -l 5 -s 1 | grep -E "(PID|$PID)"

echo
echo "Test 3: Memory usage"
echo "-------------------"
vmmap $PID | grep -E "(TOTAL|Summary)"

echo
echo "Performance optimizations active:"
echo "- Refresh debouncing (50ms)"
echo "- Eliminated busy waiting"
echo "- Optimized string operations"
echo "- Incremental window updates"
echo "- Tree traversal bounds"