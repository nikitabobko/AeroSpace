#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

all=1
antlr=0
complgen=0
while [[ $# -gt 0 ]]; do
    case $1 in
        --antlr)
            antlr=1
            all=0
            shift
            ;;
        --complgen)
            all=0
            complgen=1
            shift
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if test $all == 1 || test $antlr == 1; then
    if ! (./.deps/python-venv/bin/antlr4 | grep -q 4.13.1); then
        python3 -m venv .deps/python-venv
        source .deps/python-venv/bin/activate
        python3 -m pip install 'antlr4-tools==0.2.1'
    fi
fi

if test $all == 1 || test $complgen == 1; then
    if test "$(./.deps/cargo-root/bin/complgen version)" != cacb3970eb; then
        cargo install --git https://github.com/adaszko/complgen --rev cacb3970eb --root ./.deps/cargo-root
    fi
fi
