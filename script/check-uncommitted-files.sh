#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

if ! test -z "$(git status --porcelain)"; then
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo !!! Uncommitted files detected !!!
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    git diff | sed 's/^/    /'
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo !!! Uncommitted files detected !!!
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    exit 1
fi
