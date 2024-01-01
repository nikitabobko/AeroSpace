#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

if [ ! -z "$(git status --porcelain)" ]; then
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    echo !!! Uncommitted files detected !!!
    echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    git status
    exit 1
fi
