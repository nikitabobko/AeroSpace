#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

echo "script/publish-release.sh is local-only for FlightDeck and delegates to script/release-local.sh." > /dev/stderr
exec ./script/release-local.sh "$@"
