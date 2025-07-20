#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

swift test
