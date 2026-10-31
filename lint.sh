#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./format.sh

if grep -E '( Task\.init| Task\s*\{| Task\()' -r ./Sources; then
    echo "ERROR: don't use Task.init directly. Use Task.startUnstructured instead."
    exit 1
fi

./script/install-dep.sh --swiftlint
./.deps/swiftlint/swiftlint lint --quiet

if [ "$(uname -m)" = x86_64 ]; then
    # periphery prebuild binary only runs on arm
    echo 'warning: periphery is disabled on x86_64' > /dev/stderr
else
    ./script/install-dep.sh --periphery
    # Disable superfluous comments detection because it's buggy. todo: report to periphery maintainer
    ./.deps/periphery/periphery scan --quiet \
        --strict \
        --disable-redundant-public-analysis \
        --no-superfluous-ignore-comments
fi
