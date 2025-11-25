#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

if swift test; then
    echo "✅ Swift tests have passed successfully"
else
    echo "❌ Swift tests have failed"
    exit 1
fi
