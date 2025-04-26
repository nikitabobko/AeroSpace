#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

./clean-xcode.sh
git clean -ffxd
