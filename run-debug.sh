#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./build-debug.sh
./".debug/$debug_app_launcher_name" "$@"
