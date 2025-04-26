#!/bin/bash
cd "$(dirname "$0")"
source ./script/setup.sh

./script/install-dep.sh --antlr
./.deps/python-venv/bin/antlr4 -v 4.13.1 -no-listener -Dlanguage=Swift \
    -o ./ShellParserGenerated/Sources/ShellParserGenerated \
    ./grammar/ShellLexer.g4 \
    ./grammar/ShellParser.g4


mv ./ShellParserGenerated/Sources/ShellParserGenerated/grammar/*.swift ./ShellParserGenerated/Sources/ShellParserGenerated/
rm -rf ./ShellParserGenerated/Sources/ShellParserGenerated/grammar # Antlr generates weird *.interp and *.tokens files

# Sources/ShellParserGenerated/ShellParser.swift:557:7: warning: variable '_prevctx' was written to, but never read
#                 var _prevctx: CmdContext = _localctx
sed -i '' '/_prevctx/d' ./ShellParserGenerated/Sources/ShellParserGenerated/ShellParser.swift
