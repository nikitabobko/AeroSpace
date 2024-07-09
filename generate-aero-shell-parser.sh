#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-deps.sh --antlr
source ./.deps/python-venv/bin/activate
antlr4 -no-listener -Dlanguage=Swift \
    -o ./Sources/AeroShellParserGenerated \
    ./grammar/AeroShellLexer.g4\
    ./grammar/AeroShellParser.g4

# Antlr generates weird *.interp and *.tokens files
rm ./Sources/AeroShellParserGenerated/grammar/*.interp
rm ./Sources/AeroShellParserGenerated/grammar/*.tokens
mv ./Sources/AeroShellParserGenerated/grammar/* ./Sources/AeroShellParserGenerated/
