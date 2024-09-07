#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

all=1
antlr=0
complgen=0
swiftlint=0
swiftformat=0
xcodegen=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --antlr)
            antlr=1
            all=0
            shift ;;
        --complgen)
            all=0
            complgen=1
            shift ;;
        --swiftlint)
            all=0
            swiftlint=1
            shift ;;
        --xcodegen)
            all=0
            xcodegen=1
            shift ;;
        --swiftformat)
            all=0
            swiftformat=1
            shift ;;
        *) echo "Unknown option $1"; exit 1 ;;
    esac
done

check-version() {
    version="$1"; shift
    test -f "$1" && "$@" | grep --fixed-strings -q "$version"
}

if test $all == 1; then
    bundler install
fi

if test $all == 1 || test $antlr == 1; then
    if ! check-version 4.13.1 ./.deps/python-venv/bin/antlr4 -v 4.13.1; then
        python3 -m venv .deps/python-venv
        source .deps/python-venv/bin/activate
        python3 -m pip install 'antlr4-tools==0.2.1'
    fi
fi

if test $all == 1 || test $complgen == 1; then
    if ! check-version cacb3970eb ./.deps/cargo-root/bin/complgen version; then
        cargo install --git https://github.com/adaszko/complgen --rev cacb3970eb --root ./.deps/cargo-root
    fi
fi

if test $all == 1 || test $swiftlint == 1; then
    if ! check-version 0.56.2 ./swift-exec-deps/.build/debug/swiftlint --version; then
        swift run --package-path ./swift-exec-deps swiftlint --version
    fi
fi

if test $all == 1 || test $xcodegen == 1; then
    if ! check-version 2.42.0 ./swift-exec-deps/.build/debug/xcodegen --version; then
        swift run --package-path ./swift-exec-deps xcodegen --version
    fi
fi

if test $all == 1 || test $swiftformat == 1; then
    if ! check-version 0.54.4 ./swift-exec-deps/.build/debug/swiftformat --version; then
        swift run --package-path ./swift-exec-deps swiftformat --version
    fi
fi
