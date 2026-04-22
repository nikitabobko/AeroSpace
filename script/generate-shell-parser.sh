#!/bin/bash
cd "$(dirname "$0")/.."
source ./script/setup.sh

antlr_stderr=$(mktemp)
if ! antlr4 -v "$antlr_version" -no-listener -Dlanguage=Swift \
    -o ./ShellParserGenerated/Sources/ShellParserGenerated \
    ./grammar/ShellLexer.g4 \
    ./grammar/ShellParser.g4 2>"$antlr_stderr"
then
    cat "$antlr_stderr" >&2
    rm -f "$antlr_stderr"
    exit 1
fi

# ANTLR 4.13.1 emits two known bogus Swift template warnings here.
# Filter only those lines and surface everything else.
grep -F -v "warning(22):  template error: context [/LexerFile /Lexer /dumpActions] 2:28 attribute parser isn't defined " "$antlr_stderr" | \
    grep -F -v "warning(22):  template error: context [/LexerFile /Lexer /dumpActions /accessLevelOpenOK] 1:1 no such property or can't access: null.accessLevel " >&2 || true
rm -f "$antlr_stderr"


mv ./ShellParserGenerated/Sources/ShellParserGenerated/grammar/*.swift ./ShellParserGenerated/Sources/ShellParserGenerated/
rm -rf ./ShellParserGenerated/Sources/ShellParserGenerated/grammar # Antlr generates weird *.interp and *.tokens files

# Sources/ShellParserGenerated/ShellParser.swift:557:7: warning: variable '_prevctx' was written to, but never read
#                 var _prevctx: CmdContext = _localctx
sed -i '' '/_prevctx/d' ./ShellParserGenerated/Sources/ShellParserGenerated/ShellParser.swift
