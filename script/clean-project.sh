#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./script/clean-xcode.sh
git clean -ffxd
