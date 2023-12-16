#!/usr/bin/env bash
set -e # Exit if one of commands exit with non-zero exit code
set -u # Treat unset variables and parameters other than the special parameters ‘@’ or ‘*’ as an error
set -o pipefail # Any command failed in the pipe fails the whole pipe
# set -x # Print shell commands as they are executed (or you can try -v which is less verbose)

cd "$(dirname "$0")"
rm -rf .docs && mkdir .docs

cp -r docs/*.adoc .docs
cp -r docs/assets .docs
cp -r docs/config-examples .docs

git rev-parse HEAD > .docs/version.html
if [ ! -z "$(git status --porcelain)" ]; then
    echo "git working directory is dirty" >> .docs/version.html
fi

cd .docs
    asciidoctor *.adoc
    rm -rf *.adoc
cd -

