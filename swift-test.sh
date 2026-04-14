#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

if swift test \
    | sed -E '/^Test (Suite|Case).*(started|passed)/d' \
    | sed -E '/^[[:space:]]+Executed.*with 0 failures/d' \
    | sed -E '/ [[:digit:]]+(:[[:digit:]]+)+/s/:/;/g' # Replace colons with semicolons in dates to avoid treating these lines as files in vim
then
    echo "✅ Swift tests have passed successfully"
else
    echo "❌ Swift tests have failed"
    exit 1
fi
