#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"
rm -rf .docs && mkdir .docs

cp -r docs/*.adoc .docs
cp -r docs/assets .docs
cp -r config-examples .docs

cd .docs
    asciidoctor *.adoc
    rm -rf *.adoc
cd -

