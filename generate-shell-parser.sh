#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-deps.sh --antlr
./.deps/python-venv/bin/antlr4 -v 4.13.1 -no-listener -Dlanguage=Swift \
    -o ./Sources/ShellParserGenerated \
    ./grammar/ShellLexer.g4 \
    ./grammar/ShellParser.g4

# Antlr generates weird *.interp and *.tokens files
rm ./Sources/ShellParserGenerated/grammar/*.interp
rm ./Sources/ShellParserGenerated/grammar/*.tokens
mv ./Sources/ShellParserGenerated/grammar/* ./Sources/ShellParserGenerated/
