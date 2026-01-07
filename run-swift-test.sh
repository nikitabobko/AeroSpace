#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

# Avoid date with file coordinates misinterpretation by vim via sed
if swift test | sed -E '/ [[:digit:]]+(:[[:digit:]]+)+/s/:/;/g'; then
    echo "✅ Swift tests have passed successfully"
else
    echo "❌ Swift tests have failed"
    exit 1
fi
