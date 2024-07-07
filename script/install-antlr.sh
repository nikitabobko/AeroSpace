#!/usr/bin/env bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

python3 -m venv .deps/python-venv
source .deps/python-venv/bin/activate
python3 -m pip install 'antlr4-tools==0.2.1'
