#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

node ./script/generate-command-docs.mjs

test "$(find .man -name 'flightdeck*.1' | wc -l | tr -d ' ')" = 42
git diff --exit-code -- \
    Sources/Common/cmdHelpGenerated.swift \
    Sources/Cli/subcommandDescriptionsGenerated.swift

for page in index guide commands config-reference compatibility goodies; do
    test -f "docs/$page.mdx"
done
test -f docs/docs.json
test -f docs-redirect/index.html

if find docs -name '*.adoc' -print -quit | grep -q .; then
    echo "AsciiDoc sources remain under docs/" >&2
    exit 1
fi

if grep -R "nikitabobko.github.io/AeroSpace" docs --exclude-dir=node_modules; then
    echo "Documentation links to the upstream AeroSpace documentation site" >&2
    exit 1
fi

if grep -R "saadjs.github.io/FlightDeck" docs README.md --exclude-dir=node_modules; then
    echo "Legacy FlightDeck documentation URLs remain" >&2
    exit 1
fi

echo "Docs checks passed."
