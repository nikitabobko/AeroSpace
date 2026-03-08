#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./format.sh "$@"

./script/install-dep.sh --periphery
# Disable superfluous comments detection because it's buggy. todo: report to periphery maintainer
./.deps/periphery/periphery scan --quiet \
    --strict \
    --disable-redundant-public-analysis \
    --no-superfluous-ignore-comments \
    --exclude-targets \
    ShellParserGenerated
